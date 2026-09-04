import SwiftUI

struct CPMoreView: View {
    @EnvironmentObject private var router: PortalRouter
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        NavigationStack(path: router.path(4)) {
            List {
                Section("CRM") {
                    CPNavRow("Conversations", "bubble.left.and.bubble.right", .blue, .cpConversations)
                    CPNavRow("Contacts", "person.crop.circle.badge.plus", .teal, .cpContacts)
                    CPNavRow("Follow-ups", "bell.badge", .orange, .cpFollowUps)
                    CPNavRow("Site visits", "calendar", .red, .cpMeetings)
                    CPNavRow("Call logs", "phone.badge.checkmark", .indigo, .cpCallLogs)
                    CPNavRow("Meetups", "person.3.sequence", .pink, .cpMeetups)
                }
                Section("Grow your business") {
                    CPNavRow("Leaderboard", "trophy", .yellow, .cpLeaderboard)
                    CPNavRow("AI Lead Intelligence", "brain.head.profile", .purple, .cpAIInsights)
                    CPNavRow("Content Studio", "sparkles", .pink, .cpContentStudio)
                    CPNavRow("Brochure Generator", "doc.richtext", .orange, .cpBrochure)
                    CPNavRow("WhatsApp Broadcast", "megaphone", .green, .cpBroadcast)
                    CPNavRow("Social Analytics", "chart.bar.xaxis", .blue, .cpSocialAnalytics)
                    CPNavRow("Referrals", "gift", .teal, .cpReferral)
                    CPNavRow("Loan Assist", "indianrupeesign.circle", .indigo, .cpLoanAssist)
                    CPNavRow("Community", "person.3", .mint, .cpCommunity)
                    CPNavRow("JV Opportunities", "hands.sparkles", .brown, .cpJV)
                }
                Section("Account") {
                    CPNavRow("Notifications", "bell", .red, .cpNotifications)
                    CPNavRow("Profile & verification", "person.crop.circle", .gray, .cpProfile)
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
/// Routed by value — see the note on the builder's `NavLink` for why a trailing
/// destination closure breaks navigation on the screen it opens.
struct CPNavRow: View {
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
                    .font(.footnote.weight(.semibold)).foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
        }
    }
}
