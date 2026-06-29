import Foundation
import SwiftUI
import Combine

/// The two stages of the phone-OTP flow, shared by the login and signup screens.
enum AuthStep { case details, otp }

/// Normalises any thrown error into a user-facing message for the auth screens.
func authMessage(_ error: Error) -> String {
    (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
}

/// Holds the signed-in builder's session and drives the phone-OTP login flow.
///
/// Tokens are kept in `UserDefaults` for simplicity — fine for local development.
/// For production, move them to the Keychain.
@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var user: AuthUser?
    @Published private(set) var builderId: Int?
    @Published private(set) var isAuthenticated = false

    /// The signed-in user's role, upper-cased (BUILDER / CUSTOMER / CP / …).
    var role: String { (user?.role ?? "").uppercased() }
    /// The user's phone — the key the customer portal endpoints are keyed by.
    var phone: String { user?.phone ?? "" }

    private let tokenKey = "dealio_access_token"
    private let userKey = "dealio_user"
    private let builderIdKey = "dealio_builder_id"

    private var accessToken: String? {
        didSet { APIClient.shared.authToken = accessToken }
    }

    init() {
        let defaults = UserDefaults.standard
        if let token = defaults.string(forKey: tokenKey),
           let userData = defaults.data(forKey: userKey),
           let savedUser = try? JSONDecoder().decode(AuthUser.self, from: userData) {
            self.accessToken = token
            APIClient.shared.authToken = token
            self.user = savedUser
            if defaults.object(forKey: builderIdKey) != nil {
                self.builderId = defaults.integer(forKey: builderIdKey)
            }
            self.isAuthenticated = true
        }
    }

    // MARK: Request bodies

    private struct SendOTPRequest: Encodable { let countryCode: String; let phone: String }
    private struct VerifyLoginRequest: Encodable { let phone: String; let otp: String }
    private struct VerifySignupRequest: Encodable {
        let phone: String; let otp: String; let fullName: String; let role: String; let referralCode: String?
    }
    private struct EnsureBuilderRequest: Encodable { let name: String; let email: String?; let phone: String?; let userId: Int }

    struct OTPSendResult: Decodable { let maskedPhone: String?; let demoCode: String? }
    // MARK: Flow

    /// Sends an OTP to the phone — the login endpoint for an existing user, or the
    /// signup endpoint when registering a new account.
    @discardableResult
    func sendOTP(isSignup: Bool, countryCode: String, phone: String) async throws -> OTPSendResult {
        let path = isSignup ? "/auth/signup/phone/send-otp" : "/auth/login/phone/send-otp"
        return try await APIClient.shared.post(
            path,
            body: SendOTPRequest(countryCode: countryCode, phone: phone),
            authorized: false
        )
    }

    /// Verifies a login OTP and stores the session.
    func verifyLogin(phone: String, otp: String) async throws {
        let data: AuthData = try await APIClient.shared.post(
            "/auth/login/phone/verify-otp",
            body: VerifyLoginRequest(phone: phone, otp: otp),
            authorized: false
        )
        try await finishAuth(data)
    }

    /// Verifies a signup OTP (creating the account with the chosen role) and stores
    /// the session.
    func verifySignup(phone: String, otp: String, fullName: String, role: String, referralCode: String?) async throws {
        let trimmedReferral = referralCode?.trimmingCharacters(in: .whitespaces)
        let data: AuthData = try await APIClient.shared.post(
            "/auth/signup/phone/verify-otp",
            body: VerifySignupRequest(
                phone: phone,
                otp: otp,
                fullName: fullName.trimmingCharacters(in: .whitespaces),
                role: role,
                referralCode: (trimmedReferral?.isEmpty == false) ? trimmedReferral : nil
            ),
            authorized: false
        )
        try await finishAuth(data)
    }

    /// Stores the session and resolves the builder profile (non-fatal for non-builders).
    private func finishAuth(_ data: AuthData) async throws {
        self.accessToken = data.accessToken
        self.user = data.user
        persistSession()
        self.isAuthenticated = true
        // Only builders need a builder-profile id resolved up front.
        if (data.user.role ?? "").uppercased() == "BUILDER" {
            try? await ensureBuilder()
        }
    }

    /// Returns the builder id, resolving it first if needed. Convenience for screens.
    func resolvedBuilderId() async -> Int? {
        if builderId == nil { try? await ensureBuilder() }
        return builderId
    }

    /// Resolves (creating if needed) the builder profile id used by `/builder/:id/...` routes.
    func ensureBuilder() async throws {
        guard let user else { return }
        let result: EnsureBuilderData = try await APIClient.shared.post(
            "/builder/ensure",
            body: EnsureBuilderRequest(name: user.fullName ?? "Builder", email: user.email, phone: user.phone, userId: user.id)
        )
        self.builderId = result.builderId
        UserDefaults.standard.set(result.builderId, forKey: builderIdKey)
    }

    func logout() {
        accessToken = nil
        user = nil
        builderId = nil
        isAuthenticated = false
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: tokenKey)
        defaults.removeObject(forKey: userKey)
        defaults.removeObject(forKey: builderIdKey)
    }

    private func persistSession() {
        let defaults = UserDefaults.standard
        defaults.set(accessToken, forKey: tokenKey)
        if let user, let data = try? JSONEncoder().encode(user) {
            defaults.set(data, forKey: userKey)
        }
    }
}
