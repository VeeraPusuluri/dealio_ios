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
}

struct CustomerJourneyView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = JourneyModel()

    var body: some View {
        NavigationStack {
            Group {
                if model.loading {
                    ProgressView()
                } else if let error = model.error {
                    ErrorBanner(message: error).padding()
                } else if model.deals.isEmpty {
                    ContentUnavailableView("Your journey starts here",
                        systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                        description: Text("Once you book a home, track its progress here."))
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(model.deals) { deal in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(deal.projectName ?? "Booking").font(.headline)
                                        Spacer()
                                        StatusBadge(text: deal.dealStatus ?? "—", color: statusColor(deal.dealStatus))
                                    }
                                    HStack(spacing: 14) {
                                        if let value = deal.dealValue, value > 0 {
                                            Label(Money.inr(value), systemImage: "indianrupeesign.circle").font(.subheadline.weight(.semibold))
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
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.dealioMist.ignoresSafeArea())
            .navigationTitle("Journey")
            .task { await model.load(phone: auth.phone) }
            .refreshable { await model.load(phone: auth.phone) }
        }
    }
}
