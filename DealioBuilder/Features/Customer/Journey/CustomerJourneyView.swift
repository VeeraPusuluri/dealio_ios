import SwiftUI

@MainActor
final class JourneyModel: ObservableObject {
    @Published var deals: [CustomerDeal] = []
    @Published var loading = true
    @Published var error: String?

    func load(phone: String) async {
        loading = deals.isEmpty
        error = nil
        do {
            deals = try await APIClient.shared.get("/portal/customer/deals?phone=\(phone)")
        } catch { self.error = authMessage(error) }
        loading = false
    }

    /// The buyer's own bookings as move-queue rows.
    var moves: [MoveItem] {
        deals.map { deal in
            MoveItem(
                dealId: deal.dealId,
                title: deal.projectName ?? "Your home",
                subtitle: deal.builderName ?? "",
                rawStatus: deal.dealStatus ?? "",
                cpAgreed: deal.cpAgreed ?? false,
                customerConfirmed: deal.customerConfirmed ?? false,
                idleDays: daysSince(deal.updatedAt ?? deal.createdAt)
            )
        }
    }
}

/// The buyer's purchase, in the buyer's language.
///
/// The list used to print the raw pipeline status on every card, so a buyer
/// whose deal sat at "Pending Booking" read the trade's word for it. Now each
/// booking shows the five-phase track, the headline written for them, and what
/// — if anything — is waiting on them.
struct CustomerJourneyView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = JourneyModel()
    @State private var openDeal: DealRoute?

    var body: some View {
        NavigationStack {
            Group {
                if model.loading {
                    ProgressView()
                } else if let error = model.error {
                    ErrorBanner(message: error).padding()
                } else if model.deals.isEmpty {
                    ContentUnavailableView(
                        "Your journey starts here",
                        systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                        description: Text("Once you book a home, track its progress here.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            MoveQueue(
                                viewer: .customer,
                                items: model.moves,
                                onOpen: { openDeal = DealRoute(id: $0) },
                                emptyMessage: "Nothing needs you right now — we'll tell you the moment it does."
                            )
                            .padding(.horizontal)

                            ForEach(model.deals) { deal in
                                card(deal)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.dealioMist.ignoresSafeArea())
            .navigationTitle("Journey")
            .navigationDestination(item: $openDeal) { route in
                CustomerDealRoomView(
                    dealId: route.id,
                    title: model.deals.first { $0.dealId == route.id }?.projectName ?? "Your home"
                )
            }
            .task { await model.load(phone: auth.phone) }
            .refreshable { await model.load(phone: auth.phone) }
        }
    }

    private func card(_ deal: CustomerDeal) -> some View {
        Button { openDeal = DealRoute(id: deal.dealId) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(deal.projectName ?? "Your booking").font(.headline)
                        // The buyer reads the headline, never the stage.
                        Text(buyerHeadline(deal.dealStatus))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }

                PhaseTrack(current: phaseOf(deal.dealStatus), accent: .dealioOrange)

                HStack(spacing: 14) {
                    if let value = deal.dealValue, value > 0 {
                        Label(Money.inr(value), systemImage: "indianrupeesign.circle")
                            .font(.subheadline.weight(.semibold))
                    }
                    if let loan = deal.loanStatus {
                        Label(loan, systemImage: "creditcard").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let cp = deal.cpName {
                    Text("via \(cp)").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
}
