import SwiftUI

struct BuilderDemandLettersView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderDealsModel()
    @State private var expanded: Int?

    private let active = ["Booked", "Negotiation", "Agreement", "Loan Application Created", "Loan Sanctioned"]
    private var deals: [Deal] { model.deals.filter { active.contains($0.status ?? "") } }

    var body: some View {
        Group {
            if model.loading { ProgressView() }
            else if let error = model.error { ErrorBanner(message: error).padding() }
            else if deals.isEmpty {
                ContentUnavailableView("No active deals", systemImage: "doc.plaintext",
                    description: Text("Demand letters are available for Booked and later stages."))
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(deals) { deal in card(deal) }
                    }.padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Demand Letters")
        .navigationBarTitleDisplayMode(.inline)
        .task { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
        .refreshable { if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) } }
    }

    private func isPaid(_ i: Installment) -> Bool { (i.status ?? "").lowercased() == "paid" }

    private func card(_ deal: Deal) -> some View {
        let schedule = deal.paymentSchedule ?? []
        var paid = 0.0, pending = 0.0
        for i in schedule { if isPaid(i) { paid += i.amount ?? 0 } else { pending += i.amount ?? 0 } }
        let paidCount = schedule.filter(isPaid).count
        return VStack(alignment: .leading, spacing: 10) {
            Button { withAnimation(.snappy) { expanded = expanded == deal.id ? nil : deal.id } } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(deal.customerName ?? "Customer").font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                        Text("\(deal.projectName ?? "—") · \(deal.status ?? "")").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Money.inr(deal.dealValue)).font(.caption.weight(.bold)).foregroundStyle(.brandTeal)
                        Text("\(paidCount)/\(schedule.count) paid")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }.buttonStyle(.plain)

            if expanded == deal.id {
                HStack(spacing: 8) {
                    miniStat("Received", Money.inr(paid), .green)
                    miniStat("Pending", Money.inr(pending), .orange)
                }
                if schedule.isEmpty {
                    Text("No demand letters recorded for this deal yet.").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(schedule) { inst in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(inst.installment ?? "Installment").font(.caption.weight(.semibold))
                                Text("\(Money.inr(inst.amount)) · due \(inst.dueDate ?? "")").font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusBadge(text: inst.status ?? "Pending", color: statusColor(inst.status))
                        }
                        .padding(10).background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func miniStat(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.bold)).foregroundStyle(tint)
        }.frame(maxWidth: .infinity).padding(8).background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
    }
}
