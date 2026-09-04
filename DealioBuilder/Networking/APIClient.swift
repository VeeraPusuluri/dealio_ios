import Foundation

/// Thin async wrapper over `URLSession` that speaks the Dealio `{ ok, message, data }`
/// envelope and attaches the bearer token.
///
/// Mirrors the Android `ApiClient` + Retrofit interfaces: every verb the backend
/// exposes is available here, plus `…Void` variants for the endpoints that answer
/// with an envelope carrying no `data` (mark-read, delete, RSVP…).
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

    /// The envelope with the payload thrown away — for endpoints that answer
    /// `{ ok: true }` and nothing else.
    private struct BareEnvelope: Decodable {
        let ok: Bool
        let message: String?
    }

    private struct Empty: Encodable {}

    // MARK: - Verbs returning a decoded payload

    func get<T: Decodable>(_ path: String, authorized: Bool = true) async throws -> T {
        try await send(path, method: "GET", body: Empty?.none, authorized: authorized)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B, authorized: Bool = true) async throws -> T {
        try await send(path, method: "POST", body: body, authorized: authorized)
    }

    /// POST with no request body — the shape used by `/threads/:id/read`,
    /// `/deals/:id/nudge`, meetup cancel, and friends.
    func post<T: Decodable>(_ path: String, authorized: Bool = true) async throws -> T {
        try await send(path, method: "POST", body: Empty?.none, authorized: authorized)
    }

    func patch<T: Decodable, B: Encodable>(_ path: String, body: B, authorized: Bool = true) async throws -> T {
        try await send(path, method: "PATCH", body: body, authorized: authorized)
    }

    func patch<T: Decodable>(_ path: String, authorized: Bool = true) async throws -> T {
        try await send(path, method: "PATCH", body: Empty?.none, authorized: authorized)
    }

    func put<T: Decodable, B: Encodable>(_ path: String, body: B, authorized: Bool = true) async throws -> T {
        try await send(path, method: "PUT", body: body, authorized: authorized)
    }

    func delete<T: Decodable>(_ path: String, authorized: Bool = true) async throws -> T {
        try await send(path, method: "DELETE", body: Empty?.none, authorized: authorized)
    }

    // MARK: - Verbs that discard the payload
    //
    // The envelope's `data` is optional on the wire, so insisting on it would turn
    // a successful `{ ok: true }` into a decoding error. These check `ok` and stop.

    func postVoid<B: Encodable>(_ path: String, body: B, authorized: Bool = true) async throws {
        try await sendVoid(path, method: "POST", body: body, authorized: authorized)
    }

    func postVoid(_ path: String, authorized: Bool = true) async throws {
        try await sendVoid(path, method: "POST", body: Empty?.none, authorized: authorized)
    }

    func patchVoid<B: Encodable>(_ path: String, body: B, authorized: Bool = true) async throws {
        try await sendVoid(path, method: "PATCH", body: body, authorized: authorized)
    }

    func patchVoid(_ path: String, authorized: Bool = true) async throws {
        try await sendVoid(path, method: "PATCH", body: Empty?.none, authorized: authorized)
    }

    func putVoid<B: Encodable>(_ path: String, body: B, authorized: Bool = true) async throws {
        try await sendVoid(path, method: "PUT", body: body, authorized: authorized)
    }

    func deleteVoid(_ path: String, authorized: Bool = true) async throws {
        try await sendVoid(path, method: "DELETE", body: Empty?.none, authorized: authorized)
    }

    // MARK: - Query strings

    /// Appends `?k=v&…` to a path, percent-encoding each value and dropping nils.
    ///
    /// Retrofit does this for `@Query` parameters; without it every caller
    /// hand-rolls string interpolation and forgets to escape the city name.
    static func query(_ path: String, _ items: [String: String?]) -> String {
        let pairs = items.compactMap { key, value -> URLQueryItem? in
            guard let value, !value.isEmpty else { return nil }
            return URLQueryItem(name: key, value: value)
        }
        guard !pairs.isEmpty else { return path }
        var comps = URLComponents()
        comps.queryItems = pairs.sorted { $0.name < $1.name }
        return path + "?" + (comps.percentEncodedQuery ?? "")
    }

    // MARK: - Multipart

    /// Uploads a single file as `multipart/form-data`, with optional extra text fields
    /// (e.g. `docType`). Mirrors the backend's `multer` single-file upload endpoints.
    func upload<T: Decodable>(
        _ path: String, fileData: Data, fileName: String, mimeType: String,
        fields: [String: String] = [:], fieldName: String = "file", authorized: Bool = true
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
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await perform(request)
        return try decode(data, response)
    }

    // MARK: - Plumbing

    private func request<B: Encodable>(
        _ path: String, method: String, body: B?, authorized: Bool
    ) throws -> URLRequest {
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
        return request
    }

    private func send<T: Decodable, B: Encodable>(
        _ path: String, method: String, body: B?, authorized: Bool
    ) async throws -> T {
        let (data, response) = try await perform(request(path, method: method, body: body, authorized: authorized))
        return try decode(data, response)
    }

    private func sendVoid<B: Encodable>(
        _ path: String, method: String, body: B?, authorized: Bool
    ) async throws {
        let (data, response) = try await perform(request(path, method: method, body: body, authorized: authorized))
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 { throw APIError.unauthorized }
        if let envelope = try? JSONDecoder().decode(BareEnvelope.self, from: data) {
            guard envelope.ok else {
                throw APIError.server(envelope.message ?? "Request failed (\(http.statusCode)).")
            }
            return
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.server("Request failed (\(http.statusCode)).")
        }
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
            // A non-2xx that didn't carry a readable envelope: report the status,
            // but prefer the envelope's own message when the server sent one.
            if let bare = try? JSONDecoder().decode(BareEnvelope.self, from: data), !bare.ok {
                throw APIError.server(bare.message ?? "Request failed (\(http.statusCode)).")
            }
            if !(200...299).contains(http.statusCode) {
                throw APIError.server("Request failed (\(http.statusCode)).")
            }
            throw APIError.decoding(error)
        }
    }
}
