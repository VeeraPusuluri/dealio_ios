import SwiftUI

struct MainTabView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            OverviewView(selection: $selection)
                .tabItem { Label("Overview", systemImage: "square.grid.2x2") }.tag(0)
            ProjectsView()
                .tabItem { Label("Projects", systemImage: "building.2") }.tag(1)
            LeadsView()
                .tabItem { Label("Leads", systemImage: "person.2") }.tag(2)
            DealsView()
                .tabItem { Label("Deals", systemImage: "doc.text") }.tag(3)
            BuilderMoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }.tag(4)
        }
        .tint(.brandTeal)
    }
}
