import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case server(String)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid request URL."
        case .invalidResponse:
            return "Unexpected response from the server."
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .server(let message):
            return message
        case .decoding:
            return "Couldn't read the server response."
        case .transport:
            return "Can't reach the server. Make sure the backend is running at \(AppConfig.apiBaseURL.absoluteString)."
        }
    }
}
