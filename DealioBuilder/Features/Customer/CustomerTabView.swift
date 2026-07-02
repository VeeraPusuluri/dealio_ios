import SwiftUI

/// The customer app shell. Keeps a native `TabView` for page/state preservation
/// but hides the system tab bar and floats a custom pill nav on top (see
/// `FloatingTabBar`) whose icons bounce on tap.
struct CustomerTabView: View {
    @State private var selection = 0

    private let items: [FloatingTabItem] = [
        .init(icon: "house.fill", label: "Explore"),
        .init(icon: "calendar", label: "Visits"),
        .init(icon: "point.topleft.down.to.point.bottomright.curvepath", label: "Journey"),
        .init(icon: "bookmark.fill", label: "Saved"),
        .init(icon: "person.fill", label: "Profile"),
    ]

    var body: some View {
        FloatingTabShell(items: items, selection: $selection) {
            TabView(selection: $selection) {
                ExploreView().tag(0).modifier(FloatingTabBarPage())
                CustomerVisitsView().tag(1).modifier(FloatingTabBarPage())
                CustomerJourneyView().tag(2).modifier(FloatingTabBarPage())
                SavedView().tag(3).modifier(FloatingTabBarPage())
                CustomerProfileView().tag(4).modifier(FloatingTabBarPage())
            }
        }
    }
}
