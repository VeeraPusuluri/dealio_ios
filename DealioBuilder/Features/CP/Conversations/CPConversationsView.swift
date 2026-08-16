import SwiftUI

/// The channel partner's inbox — one row per *thread*, not per deal.
///
/// A CP talks to the builder and to the buyer on every deal, plus the three-way
/// group once one exists. The old list showed one row per lead and only ever
/// opened the builder side, so the buyer conversation had no way in at all.
struct CPConversationsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPLeadsModel()
    @State private var open: DealThreadRoute?

    private var cpUserId: Int { auth.user?.id ?? 0 }

    private var inboxDeals: [InboxDeal] {
        model.leads.map { lead in
            InboxDeal(
                dealId: lead.id,
                title: lead.customerName ?? "Customer",
                subtitle: lead.projectName ?? "",
                rawStatus: lead.status ?? "",
                // The CP is on every deal they referred, so the group and the
                // builder pair always exist for them.
                hasCp: true,
                cpName: auth.user?.fullName ?? "You",
                customerName: lead.customerName
            )
        }
    }

    var body: some View {
        Group {
            if model.loading {
                ProgressView()
            } else if let error = model.error {
                ErrorBanner(message: error).padding()
            } else {
                ConversationInbox(viewer: .cp, deals: inboxDeals) { dealId, recipientRole in
                    open = DealThreadRoute(dealId: dealId, recipientRole: recipientRole)
                } empty: {
                    ContentUnavailableView(
                        "No conversations yet",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Refer a lead to start talking to the customer and the builder.")
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Conversations")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $open) { route in
            CPDealDetailView(dealId: route.dealId, title: title(for: route.dealId))
        }
        .task { await model.load(cpUserId: cpUserId) }
        .refreshable { await model.load(cpUserId: cpUserId) }
    }

    private func title(for dealId: Int) -> String {
        model.leads.first { $0.id == dealId }?.customerName ?? "Conversation"
    }
}
