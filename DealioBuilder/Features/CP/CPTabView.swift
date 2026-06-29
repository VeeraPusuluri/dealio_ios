import SwiftUI

/// The channel-partner app shell — native iOS tab bar mirroring the Android CP app.
struct CPTabView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            CPOverviewView(selection: $selection)
                .tabItem { Label("Home", systemImage: "square.grid.2x2") }.tag(0)
            CPLeadsView()
                .tabItem { Label("Leads", systemImage: "person.2") }.tag(1)
            CPProjectsView()
                .tabItem { Label("Projects", systemImage: "building.2") }.tag(2)
            CPEarningsView()
                .tabItem { Label("Earnings", systemImage: "indianrupeesign.circle") }.tag(3)
            CPMoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }.tag(4)
        }
        .tint(.brandTeal)
    }
}
