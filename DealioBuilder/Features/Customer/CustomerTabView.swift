import SwiftUI

/// The customer app shell. Keeps a native `TabView` for page/state preservation
/// but hides the system tab bar and floats a custom pill nav on top (see
/// `FloatingTabBar`) whose icons bounce on tap.
struct CustomerTabView: View {
    @EnvironmentObject private var deepLink: DeepLinkCenter
    @StateObject private var router = PortalRouter(portal: .customer)

    private let items: [FloatingTabItem] = [
        .init(icon: "house.fill", label: "Explore"),
        .init(icon: "calendar", label: "Visits"),
        .init(icon: "point.topleft.down.to.point.bottomright.curvepath", label: "Journey"),
        .init(icon: "bookmark.fill", label: "Saved"),
        .init(icon: "person.fill", label: "Profile"),
    ]

    var body: some View {
        FloatingTabShell(items: items, selection: $router.selection) {
            TabView(selection: $router.selection) {
                ExploreView().tag(0).modifier(FloatingTabBarPage())
                CustomerVisitsView().tag(1).modifier(FloatingTabBarPage())
                CustomerJourneyView().tag(2).modifier(FloatingTabBarPage())
                SavedView().tag(3).modifier(FloatingTabBarPage())
                CustomerProfileView().tag(4).modifier(FloatingTabBarPage())
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
