import Foundation

/// Sends the device's FCM token to the backend so the user can receive pushes.
/// The token can arrive before login, so we cache it and (re)register whenever
/// we have both a token and an auth session.
final class PushRegistrar {
    static let shared = PushRegistrar()
    private init() {}

    private var latestToken: String?

    private struct DeviceTokenRequest: Encodable {
        let token: String
        let platform: String
    }
    private struct DeviceTokenResponse: Decodable {
        let id: Int?
    }

    /// Called when FCM hands us a (new) registration token.
    func updateToken(_ token: String) {
        latestToken = token
        Task { await registerIfPossible() }
    }

    /// Registers the cached token if we're authenticated; no-op otherwise.
    func registerIfPossible() async {
        guard let token = latestToken, APIClient.shared.authToken != nil else { return }
        do {
            let _: DeviceTokenResponse = try await APIClient.shared.post(
                "/auth/device-token",
                body: DeviceTokenRequest(token: token, platform: "ios"),
                authorized: true
            )
        } catch {
            print("[Push] device-token registration failed: \(error)")
        }
    }
}
