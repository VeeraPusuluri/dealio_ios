import SwiftUI

struct BuilderMoreView: View {
    @EnvironmentObject private var router: PortalRouter
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        NavigationStack(path: router.path(4)) {
            List {
                Section("Workspace") {
                    NavLink("Conversations", "bubble.left.and.bubble.right", .blue, .builderConversations)
                    NavLink("Site Visits", "calendar", .cyan, .builderMeetings)
                    NavLink("Commissions", "indianrupeesign.circle", .green, .builderCommissions)
                    NavLink("Demand Letters", "doc.plaintext", .brown, .builderDemandLetters)
                    NavLink("Loan Cases", "creditcard", .indigo, .builderLoans)
                    NavLink("Analytics", "chart.bar.xaxis", .red, .builderAnalytics)
                    NavLink("Inventory", "square.grid.3x3", .orange, .builderUnits)
                    NavLink("Shortlists", "heart.text.square", .pink, .builderShortlists)
                }
                Section("Compliance & marketing") {
                    NavLink("RERA Compliance", "checkmark.seal", .green, .builderRERA)
                    NavLink("Documents", "folder", .orange, .builderDocuments)
                    NavLink("Virtual Tours", "play.rectangle", .pink, .builderVirtualTours)
                    NavLink("Broadcast", "megaphone", .purple, .builderBroadcast)
                }
                Section("Tools") {
                    NavLink("AI Assistant", "sparkles", .purple, .builderAI)
                    NavLink("CP Performance", "person.2.badge.gearshape", .indigo, .builderCPPerformance)
                    NavLink("Possession Tracker", "house.lodge", .teal, .builderPossession)
                    NavLink("Snagging", "wrench.and.screwdriver", .pink, .builderSnagging)
                }
                Section("Account") {
                    NavLink("New Project", "plus.app", .green, .builderProjectForm(nil))
                    NavLink("Notifications", "bell", .red, .builderNotifications)
                    NavLink("Settings", "gearshape", .gray, .builderSettings)
                }
                Section {
                    Button(role: .destructive) { auth.logout() } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .portalDestinations()
            .navigationTitle("More")
        }
    }
}

/// A labelled navigation row with a tinted SF Symbol badge.
///
/// Routed by value, not by a trailing destination closure. Two reasons: a
/// destination closure is built for every visible row on each render (each one
/// allocating its screen's model), and — the reason this menu was rewritten —
/// once a stack is entered through a destination-based link, the value-based
/// links on the screen it opened stop pushing. That is what made tapping a
/// commission row do nothing.
private struct NavLink: View {
    let title: String
    let systemImage: String
    let tint: Color
    let route: PortalRoute

    init(_ title: String, _ systemImage: String, _ tint: Color, _ route: PortalRoute) {
        self.title = title; self.systemImage = systemImage; self.tint = tint; self.route = route
    }

    var body: some View {
        NavigationLink(value: route) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
        }
    }
}
