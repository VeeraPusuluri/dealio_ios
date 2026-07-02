import SwiftUI

/// Full-screen lock shown over the authenticated app when the app-lock is engaged.
/// Auto-prompts Face ID / Touch ID / passcode on appear, with a manual retry button.
struct LockView: View {
    @EnvironmentObject private var appLock: AppLockManager

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.dealioNavyDeep, .dealioNavyMid, .dealioTealDeep],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 88, height: 88)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(spacing: 6) {
                    (Text("Deal").foregroundColor(.white)
                        + Text("io").foregroundColor(.dealioTealBright))
                        .font(.system(size: 28, weight: .bold))
                    Text("Locked for your security")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Button {
                    Task { await appLock.unlock() }
                } label: {
                    Label("Unlock with \(appLock.methodName)", systemImage: appLock.methodSymbol)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)

                if let error = appLock.authError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
        }
        .task { await appLock.unlock() }
    }
}

/// A settings row that toggles the biometric app-lock. Enabling prompts for
/// authentication first; drop it into any role's profile/settings card.
struct AppLockToggle: View {
    @EnvironmentObject private var appLock: AppLockManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: appLock.methodSymbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(
                    LinearGradient(colors: [.dealioTeal, .dealioTealDeep], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text("App Lock").font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                Text(appLock.isAvailable
                     ? "Require \(appLock.methodName) to open Dealio"
                     : "Set up Face ID, Touch ID, or a passcode first")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { appLock.isEnabled },
                set: { on in Task { if on { await appLock.enable() } else { appLock.disable() } } }
            ))
            .labelsHidden()
            .tint(.brandTeal)
            .disabled(!appLock.isAvailable)
        }
        .padding(.vertical, 11)
    }
}
