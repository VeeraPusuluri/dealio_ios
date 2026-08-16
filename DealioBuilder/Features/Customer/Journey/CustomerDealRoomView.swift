import SwiftUI

/// The buyer's view of one booking.
///
/// The customer portal had no deal screen at all — the journey list was the end
/// of the road, so a buyer could not see where their purchase stood or reply to
/// the builder without going through a separate Conversations page. This is the
/// same `DealRoom` the other two roles open, in the buyer's register: the exact
/// pipeline stage is hidden, the copy is theirs, and the party rail offers only
/// the threads the backend will let them read.
@MainActor
final class CustomerDealRoomModel: ObservableObject {
    @Published var deal: CustomerDeal?
    @Published var loading = true
    @Published var error: String?

    /// `/portal/customer/deals` is keyed by phone and returns the whole list, so
    /// one booking is picked out of it rather than fetched on its own.
    func load(phone: String, dealId: Int) async {
        loading = deal == nil
        error = nil
        do {
            let deals: [CustomerDeal] = try await APIClient.shared.get("/portal/customer/deals?phone=\(phone)")
            deal = deals.first { $0.dealId == dealId }
            if deal == nil { error = "This booking is no longer on your account." }
        } catch {
            self.error = authMessage(error)
        }
        loading = false
    }

    /// `recipientRole` picks the thread: `builder` | `cp` | `group`.
    func send(phone: String, dealId: Int, text: String, to recipientRole: String) async {
        struct Body: Encodable { let phone: String; let recipientRole: String; let message: String }
        do {
            try await APIClient.shared.call(
                "/portal/customer/deals/\(dealId)/messages",
                body: Body(phone: phone, recipientRole: recipientRole, message: text)
            )
        } catch {
            self.error = authMessage(error)
        }
        await load(phone: phone, dealId: dealId)
    }

    /// Accepts the price the builder has quoted, moving the deal on.
    func acceptNegotiation(phone: String, dealId: Int) async {
        struct Body: Encodable { let phone: String }
        do {
            try await APIClient.shared.call(
                "/portal/customer/deals/\(dealId)/accept-negotiation",
                method: "PATCH",
                body: Body(phone: phone)
            )
        } catch {
            self.error = authMessage(error)
        }
        await load(phone: phone, dealId: dealId)
    }
}

struct CustomerDealRoomView: View {
    let dealId: Int
    let title: String

    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CustomerDealRoomModel()
    @State private var route: StageTarget?

    var body: some View {
        Group {
            if model.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let deal = model.deal {
                DealRoom(
                    viewer: .customer,
                    deal: roomData(deal),
                    onSend: { text, recipient in
                        await model.send(phone: auth.phone, dealId: dealId, text: text, to: recipient)
                    },
                    onStageAction: { route = $0 }
                )
            } else {
                VStack {
                    ErrorBanner(message: model.error ?? "Couldn't load this booking.").padding()
                    Spacer()
                }
            }
        }
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $route) { target in
            switch target {
            case .customerVisits: CustomerVisitsView()
            case .customerLoan: CustomerLoansView()
            default: EmptyView()
            }
        }
        .task { await model.load(phone: auth.phone, dealId: dealId) }
    }

    private func roomData(_ deal: CustomerDeal) -> DealRoomData {
        DealRoomData(
            id: deal.dealId,
            status: deal.dealStatus,
            title: deal.projectName ?? title,
            subtitle: deal.builderName ?? "",
            builderName: deal.builderName,
            cpName: deal.cpName,
            // The buyer is one of the parties; the rail labels their own side.
            customerName: auth.user?.fullName ?? "You",
            cpAgreed: deal.cpAgreed ?? false,
            customerConfirmed: deal.customerConfirmed ?? false,
            idleDays: daysSince(deal.updatedAt ?? deal.createdAt),
            messages: deal.messages ?? [],
            events: deal.events ?? []
        )
    }
}
