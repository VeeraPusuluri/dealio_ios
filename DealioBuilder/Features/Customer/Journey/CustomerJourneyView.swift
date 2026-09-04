import SwiftUI

/// Every home the buyer is in the running for.
///
/// The move queue comes first — a buyer with nothing to do gets told so, rather
/// than an absence they have to interpret — then one card per deal, each showing
/// the buyer's five-phase track rather than the sales ladder behind it. Mirrors
/// Android's `ui/customer/journey/JourneyScreen.kt`.

@MainActor
final class JourneyModel: ObservableObject {
    @Published var deals: [CustomerDeal] = []
    @Published var loading = true
    @Published var error: String?

    func load(phone: String) async {
        loading = deals.isEmpty
        error = nil
        do { deals = try await CustomerService.myDeals(phone: phone) }
        catch { self.error = authMessage(error) }
        loading = false
    }
}

struct CustomerJourneyView: View {
    @EnvironmentObject private var router: PortalRouter
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = JourneyModel()
    @State private var openDeal: Int?

    private var totalValue: Double { model.deals.reduce(0) { $0 + ($1.dealValue ?? 0) } }
    private var bookedCount: Int {
        model.deals.filter { DealFlow.phase($0.dealStatus).rawValue >= JourneyPhase.booking.rawValue }.count
    }

    var body: some View {
        NavigationStack(path: router.path(2)) {
            Group {
                if model.loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = model.error, model.deals.isEmpty {
                    VStack(spacing: 14) {
                        ErrorBanner(message: error)
                        Button("Try again") { Task { await model.load(phone: auth.phone) } }
                            .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .padding()
                } else if model.deals.isEmpty {
                    ContentUnavailableView("Your journey starts here",
                        systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                        description: Text("Book a visit or shortlist a home and you'll be able to track every step of it from this tab."))
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            summaryStats

                            MoveQueue(
                                viewer: .customer,
                                items: model.deals.map { deal in
                                    MoveItem(dealId: deal.dealId, title: deal.projectName,
                                             subtitle: deal.builderName ?? "Your purchase",
                                             rawStatus: deal.dealStatus,
                                             cpAgreed: deal.cpAgreed,
                                             customerConfirmed: deal.customerConfirmed,
                                             idleDays: idleDaysSince(deal.createdAt))
                                },
                                onOpen: { openDeal = $0 },
                                accent: .customerAccent,
                                emptyMessage: "Everything is with your builder or advisor right now."
                            )

                            ForEach(model.deals) { deal in
                                Button { openDeal = deal.dealId } label: { dealCard(deal) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                    .refreshable { await model.load(phone: auth.phone) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.customerSurface.ignoresSafeArea())
            .portalDestinations()
            .navigationTitle("My journey")
            .navigationDestination(item: $openDeal) { id in
                CustomerDealRoomView(dealId: id)
            }
            .task { await model.load(phone: auth.phone) }
        }
    }

    private var summaryStats: some View {
        HStack(spacing: 10) {
            stat("\(model.deals.count)", "active")
            if totalValue > 0 { stat(Money.inr(totalValue), "in play") }
            if bookedCount > 0 { stat("\(bookedCount)", "booked") }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Color.dealioTextPrimary)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold)).tracking(0.5)
                .foregroundStyle(Color.dealioTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .cardSurface(cornerRadius: 14)
    }

    private func dealCard(_ deal: CustomerDeal) -> some View {
        let phase = DealFlow.phase(deal.dealStatus)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(deal.projectName)
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(Color.dealioTextPrimary)
                        .lineLimit(2)
                    if (deal.dealValue ?? 0) > 0 {
                        Text(Money.inr(deal.dealValue))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.customerAccent)
                    }
                }
                Spacer(minLength: 8)
                // The buyer's phase, not the sales stage — every other buyer
                // surface already translates; this list was the one that did not.
                StatusBadge(text: phase.label, color: .customerAccent)
            }
            .padding(.bottom, 16)

            PhaseTrack(current: phase, accent: .customerAccent)
                .padding(.bottom, 14)

            nextStepRow(phase)

            if deal.loanCaseId != nil {
                HStack(spacing: 8) {
                    Image(systemName: "building.columns").font(.caption)
                    Text("Home loan · \(Money.inr(deal.loanAmount)) · \(deal.loanStatus ?? "Applied")")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(Color.blue)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.top, 8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    /// "Up next" hint under the track — what actually moves things along.
    private func nextStepRow(_ phase: JourneyPhase) -> some View {
        HStack(spacing: 6) {
            Text("UP NEXT")
                .font(.system(size: 9, weight: .black)).tracking(0.7)
                .foregroundStyle(Color.customerAccent)
            Text(nextStep(phase))
                .font(.system(size: 11.5))
                .foregroundStyle(Color.dealioTextSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color.customerAccent.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func nextStep(_ phase: JourneyPhase) -> String {
        switch phase {
        case .enquiry: return "Book a site visit to move forward"
        case .visit: return "Share your feedback after the visit"
        case .deal: return "Agree pricing and paperwork"
        case .booking: return "Complete your booking payment"
        case .handover: return "Registration and possession"
        }
    }
}
