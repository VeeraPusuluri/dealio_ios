import SwiftUI
import LocalAuthentication

/// Biometric app-lock. When enabled, the app requires Face ID / Touch ID (with a
/// device-passcode fallback) to be unlocked on cold launch and after returning
/// from the background. The preference is stored in `UserDefaults`.
@MainActor
final class AppLockManager: ObservableObject {
    @Published private(set) var isEnabled: Bool
    /// True while the authenticated app should be covered by the lock screen.
    @Published var isLocked = false
    @Published var authError: String?

    private let key = "dealio_app_lock_enabled"

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: key)
    }

    /// Whether the device can authenticate the owner (biometrics or passcode).
    var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Human-readable name of the primary method, for labels ("Face ID" / "Touch ID").
    var methodName: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Passcode"
        }
    }

    /// SF Symbol matching the primary method.
    var methodSymbol: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch ctx.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.fill"
        }
    }

    /// Locks the app if the feature is enabled — call on cold launch and on background.
    func lockIfEnabled() {
        if isEnabled { isLocked = true }
    }

    /// Prompts the owner-authentication policy. Returns true on success.
    private func authenticate(reason: String) async -> Bool {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "Enter Passcode"
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            authError = "Face ID / passcode isn't set up on this device."
            return false
        }
        do {
            return try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }

    /// Drives the lock screen — prompts and, on success, reveals the app.
    func unlock() async {
        authError = nil
        if await authenticate(reason: "Unlock Dealio") {
            isLocked = false
        }
    }

    /// Turns the lock on — requires a successful authentication first.
    func enable() async {
        guard isAvailable else {
            authError = "Set up Face ID, Touch ID, or a device passcode first."
            return
        }
        if await authenticate(reason: "Enable app lock") {
            isEnabled = true
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    func disable() {
        isEnabled = false
        isLocked = false
        UserDefaults.standard.set(false, forKey: key)
    }
}
