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
            // Re-register the device for push on a restored session.
            Task { await PushRegistrar.shared.registerIfPossible() }
            // The stored copy is whatever was true at the last sign-in, which
            // can be months old. Anything changed since — a new profile
            // picture, a renamed account — would otherwise never appear until
            // the session was thrown away and made again.
            Task { await refreshMe() }
        }
    }

    /// Re-reads the signed-in account from the server.
    ///
    /// Best-effort: a failure leaves the stored copy in place, which is still a
    /// usable session. Only an outright 401 means anything, and the API client
    /// already surfaces that.
    func refreshMe() async {
        guard isAuthenticated else { return }
        guard let fresh: AuthUser = try? await APIClient.shared.get("/auth/me") else { return }
        user = fresh
        persistSession()
    }

    // MARK: Request bodies

    private struct SendOTPRequest: Encodable { let countryCode: String; let phone: String }
    private struct VerifyLoginRequest: Encodable { let phone: String; let otp: String }
    private struct VerifySignupRequest: Encodable {
        let phone: String; let otp: String; let fullName: String; let role: String; let referralCode: String?
    }
    private struct EnsureBuilderRequest: Encodable { let name: String; let email: String?; let phone: String?; let userId: Int }

    struct OTPSendResult: Decodable { let maskedPhone: String?; let demoCode: String? }

    // MARK: Pre-flight

    private struct PhoneLookupRequest: Encodable { let phone: String }

    /// What the backend knows about a number before an OTP is spent on it.
    struct PhoneLookup: Decodable {
        let exists: Bool
        let suspended: Bool
        /// The account's real role, or `nil` while suspended.
        let role: String?
    }

    /// Asks the backend about a number before sending a code.
    ///
    /// Without this, someone signing in under the wrong role pill — or with no
    /// account at all — only finds out after typing a code, because the failure
    /// happens at verify time.
    func lookup(countryCode: String, phone: String) async throws -> PhoneLookup {
        try await APIClient.shared.post(
            "/auth/phone/lookup",
            body: PhoneLookupRequest(phone: e164(countryCode: countryCode, phone: phone)),
            authorized: false
        )
    }

    /// "+919876543210" — the shape the lookup keys on.
    nonisolated func e164(countryCode: String, phone: String) -> String {
        "+" + countryCode.filter(\.isNumber) + phone.filter(\.isNumber)
    }

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
        // Register this device for push now that we're authenticated.
        Task { await PushRegistrar.shared.registerIfPossible() }
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

    // MARK: Profile picture

    /// Replaces the signed-in person's picture.
    ///
    /// The updated user is written back to the store, which is the app's only
    /// copy of the account between launches — so a new photo shows on every
    /// screen at once rather than after a re-login.
    func uploadAvatar(data: Data, fileName: String, mimeType: String) async throws {
        let updated: AuthUser = try await APIClient.shared.upload(
            "/auth/me/avatar", fileData: data, fileName: fileName, mimeType: mimeType
        )
        user = updated
        persistSession()
    }

    func removeAvatar() async throws {
        let updated: AuthUser = try await APIClient.shared.delete("/auth/me/avatar")
        user = updated
        persistSession()
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
