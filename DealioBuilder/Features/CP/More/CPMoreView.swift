import SwiftUI

struct CPMoreView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        NavigationStack {
            List {
                Section("CRM") {
                    CPNavRow("Conversations", "bubble.left.and.bubble.right", .blue) { CPConversationsView() }
                    CPNavRow("Contacts", "person.crop.circle.badge.plus", .teal) { CPContactsView() }
                    CPNavRow("Follow-ups", "bell.badge", .orange) { CPFollowUpsView() }
                    CPNavRow("Meetings", "calendar", .red) { CPMeetingsView() }
                }
                Section("Grow your business") {
                    CPNavRow("Leaderboard", "trophy", .yellow) { CPLeaderboardView() }
                    CPNavRow("AI Lead Intelligence", "brain.head.profile", .purple) { CPAIInsightsView() }
                    CPNavRow("Content Studio", "sparkles", .pink) { CPContentStudioView() }
                    CPNavRow("Brochure Generator", "doc.richtext", .orange) { CPBrochureView() }
                    CPNavRow("WhatsApp Broadcast", "megaphone", .green) { CPBroadcastView() }
                    CPNavRow("Social Analytics", "chart.bar.xaxis", .blue) { CPSocialAnalyticsView() }
                    CPNavRow("Referrals", "gift", .teal) { CPReferralView() }
                    CPNavRow("Loan Assist", "indianrupeesign.circle", .indigo) { CPLoanAssistView() }
                    CPNavRow("Community", "person.3", .mint) { CPCommunityView() }
                    CPNavRow("JV Opportunities", "hands.sparkles", .brown) { CPJVView() }
                }
                Section("Account") {
                    CPNavRow("Profile & verification", "person.crop.circle", .gray) { CPProfileView() }
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

struct CPNavRow<Destination: View>: View {
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
                    .font(.footnote.weight(.semibold)).foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
        }
    }
}
