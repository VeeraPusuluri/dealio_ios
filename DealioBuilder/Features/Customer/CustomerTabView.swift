import SwiftUI

/// The customer app shell — a native iOS tab bar mirroring the Android consumer app.
struct CustomerTabView: View {
    var body: some View {
        TabView {
            ExploreView()
                .tabItem { Label("Explore", systemImage: "house") }
            CustomerVisitsView()
                .tabItem { Label("Visits", systemImage: "calendar") }
            CustomerJourneyView()
                .tabItem { Label("Journey", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }
            SavedView()
                .tabItem { Label("Saved", systemImage: "bookmark") }
            CustomerProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
        }
        .tint(.brandTeal)
    }
}
