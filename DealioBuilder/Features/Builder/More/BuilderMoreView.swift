import SwiftUI

struct BuilderMoreView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        NavigationStack {
            List {
                Section("Workspace") {
                    NavLink("Conversations", "bubble.left.and.bubble.right", .blue) { BuilderConversationsView() }
                    NavLink("Pipeline", "rectangle.stack", .brandTeal) { BuilderPipelineView() }
                    NavLink("Site Visits", "calendar", .cyan) { BuilderMeetingsView() }
                    NavLink("Commissions", "indianrupeesign.circle", .green) { BuilderCommissionsView() }
                    NavLink("Demand Letters", "doc.plaintext", .brown) { BuilderDemandLettersView() }
                    NavLink("Loan Cases", "creditcard", .indigo) { BuilderLoansView() }
                    NavLink("Analytics", "chart.bar.xaxis", .red) { BuilderAnalyticsView() }
                }
                Section("Compliance & marketing") {
                    NavLink("RERA Compliance", "checkmark.seal", .green) { BuilderRERAView() }
                    NavLink("Documents", "folder", .orange) { BuilderDocumentsView() }
                    NavLink("Virtual Tours", "play.rectangle", .pink) { BuilderVirtualToursView() }
                    NavLink("Broadcast", "megaphone", .purple) { BuilderBroadcastView() }
                }
                Section("Tools") {
                    NavLink("AI Assistant", "sparkles", .purple) { BuilderAIView() }
                    NavLink("CP Performance", "person.2.badge.gearshape", .indigo) { BuilderCPPerformanceView() }
                    NavLink("Possession Tracker", "house.lodge", .teal) { BuilderPossessionView() }
                    NavLink("Snagging", "wrench.and.screwdriver", .pink) { BuilderSnaggingView() }
                }
                Section("Account") {
                    NavLink("New Project", "plus.app", .green) { BuilderProjectFormView() }
                    NavLink("Notifications", "bell", .red) { BuilderNotificationsView() }
                    NavLink("Settings", "gearshape", .gray) { BuilderSettingsView() }
                }
                Section {
                    Button(role: .destructive) { auth.logout() } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("More")
        }
    }
}

/// A labelled navigation row with a tinted SF Symbol badge.
private struct NavLink<Destination: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let destination: () -> Destination

    init(_ title: String, _ systemImage: String, _ tint: Color, @ViewBuilder destination: @escaping () -> Destination) {
        self.title = title; self.systemImage = systemImage; self.tint = tint; self.destination = destination
    }

    var body: some View {
        NavigationLink {
            destination()
        } label: {
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
