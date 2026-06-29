import SwiftUI

@MainActor
final class CPEarningsModel: ObservableObject {
    @Published var commissions: [CpCommission] = []
    @Published var loading = true
    @Published var error: String?

    func load(cpUserId: Int) async {
        loading = commissions.isEmpty
        error = nil
        do {
            commissions = try await APIClient.shared.get("/cp/\(cpUserId)/commissions")
        } catch { self.error = authMessage(error) }
        loading = false
    }

    private func isReleased(_ c: CpCommission) -> Bool {
        let s = (c.commissionStatus ?? "").lowercased()
        return s.contains("released") || s == "paid"
    }
    var totalEarned: Double {
        var sum = 0.0
        for c in commissions where isReleased(c) { sum += c.commissionAmount ?? 0 }
        return sum
    }
    var totalPending: Double {
        var sum = 0.0
        for c in commissions where !isReleased(c) { sum += c.commissionAmount ?? 0 }
        return sum
    }
}

struct CPEarningsView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = CPEarningsModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if model.loading {
                        ProgressView().padding(.top, 40)
                    } else if let error = model.error {
                        ErrorBanner(message: error).padding(.horizontal)
                    } else {
                        HStack(spacing: 12) {
                            StatCard(title: "Released", value: Money.inr(model.totalEarned), systemImage: "checkmark.seal", tint: .green)
                            StatCard(title: "Pending", value: Money.inr(model.totalPending), systemImage: "hourglass", tint: .dealioOrange)
                        }
                        .padding(.horizontal)

                        if model.commissions.isEmpty {
                            ContentUnavailableView("No commissions yet",
                                systemImage: "indianrupeesign.circle",
                                description: Text("Earnings from your booked deals appear here."))
                                .padding(.top, 30)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(model.commissions) { c in
                                    HStack(spacing: 12) {
                                        IconBadge(systemImage: "indianrupeesign", tint: .green)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(c.customerName ?? "—").font(.subheadline.weight(.semibold)).lineLimit(1)
                                            Text(c.projectName ?? "—").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(Money.inr(c.commissionAmount)).font(.subheadline.weight(.bold))
                                            StatusBadge(text: c.commissionStatus ?? "Pending", color: statusColor(c.commissionStatus))
                                        }
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity)
                                    .cardSurface()
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .background(Color.dealioMist.ignoresSafeArea())
            .navigationTitle("Earnings")
            .task { await model.load(cpUserId: auth.user?.id ?? 0) }
            .refreshable { await model.load(cpUserId: auth.user?.id ?? 0) }
        }
    }
}
