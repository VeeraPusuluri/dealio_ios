import SwiftUI

/// The builder app shell — native `TabView` under a shared floating pill nav
/// (`FloatingTabBar`) with tap bounce.
struct MainTabView: View {
    @State private var selection = 0

    private let items: [FloatingTabItem] = [
        .init(icon: "square.grid.2x2", label: "Overview"),
        .init(icon: "building.2", label: "Projects"),
        .init(icon: "person.2", label: "Leads"),
        .init(icon: "doc.text", label: "Deals"),
        .init(icon: "ellipsis.circle", label: "More"),
    ]

    var body: some View {
        FloatingTabShell(items: items, selection: $selection) {
            TabView(selection: $selection) {
                OverviewView(selection: $selection).tag(0).modifier(FloatingTabBarPage())
                ProjectsView().tag(1).modifier(FloatingTabBarPage())
                LeadsView().tag(2).modifier(FloatingTabBarPage())
                DealsView().tag(3).modifier(FloatingTabBarPage())
                BuilderMoreView().tag(4).modifier(FloatingTabBarPage())
            }
        }
    }
}
