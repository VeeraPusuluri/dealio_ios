import Foundation

/// Thin async wrapper over `URLSession` that speaks the Dealio `{ ok, message, data }`
/// envelope and attaches the bearer token.
final class APIClient {
    static let shared = APIClient()
    private init() {}

    /// Current access token; set by `AuthStore`. `nil` when signed out.
    var authToken: String?

    private struct Envelope<T: Decodable>: Decodable {
        let ok: Bool
        let message: String?
        let data: T?
    }

    private struct Empty: Encodable {}

    func get<T: Decodable>(_ path: String, authorized: Bool = true) async throws -> T {
        try await send(path, method: "GET", body: Empty?.none, authorized: authorized)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B, authorized: Bool = true) async throws -> T {
        try await send(path, method: "POST", body: body, authorized: authorized)
    }

    /// Uploads a single file as `multipart/form-data`, with optional extra text fields
    /// (e.g. `docType`). Mirrors the backend's `multer` single-file upload endpoints.
    func upload<T: Decodable>(
        _ path: String, fileData: Data, fileName: String, mimeType: String,
        fields: [String: String] = [:], authorized: Bool = true
    ) async throws -> T {
        guard let url = URL(string: AppConfig.apiBaseURL.absoluteString + path) else {
            throw APIError.invalidURL
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if authorized, let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await perform(request)
        return try decode(data, response)
    }

    private func send<T: Decodable, B: Encodable>(
        _ path: String, method: String, body: B?, authorized: Bool
    ) async throws -> T {
        // Paths begin with "/" and are appended to the full base ("…/api") so the
        // "/api" prefix is preserved.
        guard let url = URL(string: AppConfig.apiBaseURL.absoluteString + path) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authorized, let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await perform(request)
        return try decode(data, response)
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.transport(error)
        }
    }

    private func decode<T: Decodable>(_ data: Data, _ response: URLResponse) throws -> T {
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 { throw APIError.unauthorized }

        do {
            let envelope = try JSONDecoder().decode(Envelope<T>.self, from: data)
            guard envelope.ok else {
                throw APIError.server(envelope.message ?? "Request failed (\(http.statusCode)).")
            }
            guard let value = envelope.data else { throw APIError.invalidResponse }
            return value
        } catch let apiError as APIError {
            throw apiError
        } catch {
            if !(200...299).contains(http.statusCode) {
                throw APIError.server("Request failed (\(http.statusCode)).")
            }
            throw APIError.decoding(error)
        }
    }
}
