import SwiftUI

@main
struct DealioBuilderApp: App {
    @StateObject private var auth = AuthStore()
    @StateObject private var serverMonitor = ServerStatusMonitor()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if serverMonitor.isDown {
                    ServerDownView(monitor: serverMonitor)
                        .transition(.opacity)
                } else {
                    RootView()
                        .environmentObject(auth)
                        .tint(.brandTeal)
                        .transition(.opacity)
                }

                if showSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: serverMonitor.isDown)
        }
    }
}
