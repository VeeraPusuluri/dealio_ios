import SwiftUI

/// The builder app shell — native `TabView` under a shared floating pill nav
/// (`FloatingTabBar`) with tap bounce.
struct MainTabView: View {
    @EnvironmentObject private var deepLink: DeepLinkCenter
    @StateObject private var router = PortalRouter(portal: .builder)

    private let items: [FloatingTabItem] = [
        .init(icon: "square.grid.2x2", label: "Overview"),
        .init(icon: "building.2", label: "Projects"),
        .init(icon: "person.2", label: "Pipeline"),
        .init(icon: "doc.text", label: "Deals"),
        .init(icon: "ellipsis.circle", label: "More"),
    ]

    var body: some View {
        FloatingTabShell(items: items, selection: $router.selection) {
            TabView(selection: $router.selection) {
                OverviewView(selection: $router.selection).tag(0).modifier(FloatingTabBarPage())
                ProjectsView().tag(1).modifier(FloatingTabBarPage())
                NavigationStack(path: router.path(2)) { BuilderPipelineView().portalDestinations() }.tag(2).modifier(FloatingTabBarPage())
                DealsView().tag(3).modifier(FloatingTabBarPage())
                BuilderMoreView().tag(4).modifier(FloatingTabBarPage())
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
