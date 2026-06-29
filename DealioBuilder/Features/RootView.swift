import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var showSignup = false

    var body: some View {
        if auth.isAuthenticated {
            switch auth.role {
            case "CUSTOMER": CustomerTabView()
            case "CP": CPTabView()
            case "BUILDER": MainTabView()
            default: UnsupportedRoleView()
            }
        } else if showSignup {
            SignupView(onGoToLogin: { withAnimation(.snappy) { showSignup = false } })
                .transition(.move(edge: .trailing).combined(with: .opacity))
        } else {
            LoginView(onGoToSignup: { withAnimation(.snappy) { showSignup = true } })
                .transition(.move(edge: .leading).combined(with: .opacity))
        }
    }
}
