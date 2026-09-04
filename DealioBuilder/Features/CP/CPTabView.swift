import SwiftUI

/// The channel-partner app shell — native `TabView` under a shared floating pill
/// nav (`FloatingTabBar`) with tap bounce.
struct CPTabView: View {
    @EnvironmentObject private var deepLink: DeepLinkCenter
    @StateObject private var router = PortalRouter(portal: .cp)

    private let items: [FloatingTabItem] = [
        .init(icon: "square.grid.2x2", label: "Home"),
        .init(icon: "person.2", label: "Leads"),
        .init(icon: "building.2", label: "Projects"),
        .init(icon: "indianrupeesign.circle", label: "Earnings"),
        .init(icon: "ellipsis.circle", label: "More"),
    ]

    var body: some View {
        FloatingTabShell(items: items, selection: $router.selection) {
            TabView(selection: $router.selection) {
                CPOverviewView(selection: $router.selection).tag(0).modifier(FloatingTabBarPage())
                CPLeadsView().tag(1).modifier(FloatingTabBarPage())
                CPProjectsView().tag(2).modifier(FloatingTabBarPage())
                CPEarningsView().tag(3).modifier(FloatingTabBarPage())
                CPMoreView().tag(4).modifier(FloatingTabBarPage())
            }
        }
        .environmentObject(router)
        // A notification tapped in the tray lands here, on the screen it is about.
        .task { router.follow(deepLink) }
        .onChange(of: deepLink.pending) { _, pending in
            if pending != nil { router.follow(deepLink) }
        }
    }
}
