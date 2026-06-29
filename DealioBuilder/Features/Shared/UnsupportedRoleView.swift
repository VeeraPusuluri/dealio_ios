import SwiftUI

/// Shown when a signed-in role doesn't yet have a native iOS experience.
struct UnsupportedRoleView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        VStack(spacing: 18) {
            DealioMark(size: 64)
            VStack(spacing: 6) {
                Text("Coming soon to iOS")
                    .font(.title2.weight(.bold))
                Text("The \(auth.role.capitalized) experience isn't available on iOS yet. Please use the web app for now.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(role: .destructive) { auth.logout() } label: {
                Text("Log out").font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
    }
}
