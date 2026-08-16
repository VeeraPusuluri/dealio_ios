import SwiftUI

/// The builder's inbox — one row per *thread*, not per deal.
///
/// A builder talks to the channel partner and to the buyer separately, and
/// before this the list showed one row per deal that opened whichever of the two
/// the detail screen happened to default to. Now each conversation is its own
/// row with its own unread count, and tapping one opens the deal on that thread.
struct BuilderConversationsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderDealsModel()
    @State private var open: DealThreadRoute?

    private var inboxDeals: [InboxDeal] {
        model.deals.map { deal in
            InboxDeal(
                dealId: deal.id,
                title: deal.customerName ?? "Customer",
                subtitle: deal.projectName ?? "",
                rawStatus: deal.status ?? "",
                hasCp: !(deal.cpName ?? "").isEmpty,
                cpName: deal.cpName,
                customerName: deal.customerName
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
                ConversationInbox(viewer: .builder, deals: inboxDeals) { dealId, recipientRole in
                    open = DealThreadRoute(dealId: dealId, recipientRole: recipientRole)
                } empty: {
                    ContentUnavailableView(
                        "No conversations yet",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("When a customer books a visit, your chat with them appears here.")
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Conversations")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $open) { route in
            BuilderDealDetailView(dealId: route.dealId, title: title(for: route.dealId))
        }
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
        .refreshable { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
    }

    private func title(for dealId: Int) -> String {
        model.deals.first { $0.id == dealId }?.customerName ?? "Conversation"
    }
}

/// One deal opened on one of its threads.
struct DealThreadRoute: Identifiable, Hashable {
    let dealId: Int
    let recipientRole: String
    var id: String { "\(dealId):\(recipientRole)" }
}
