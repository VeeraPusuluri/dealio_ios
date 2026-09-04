import SwiftUI

struct BuilderDemandLettersView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var model = BuilderDealsModel()
    @State private var expanded: Int?

    /// Deals far enough along to have a payment schedule. Folded onto the
    /// canonical ladder first, so a row still carrying "Loan Sanctioned" is
    /// recognised as Booked rather than filtered out.
    private var deals: [Deal] {
        model.deals.filter {
            ["Negotiation", "Agreement", "Pending Booking", "Booked", "Closed"]
                .contains(DealFlow.canonicalStage($0.status) ?? "")
        }
    }

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

    private func isPaid(_ instalment: Installment) -> Bool {
        (instalment.status ?? "").lowercased() == "paid"
    }

    /// An unpaid instalment whose due date has gone by. Worth its own colour: a
    /// builder scanning this page is looking for the money that has not arrived,
    /// not the money that is not due yet.
    private func isOverdue(_ instalment: Installment) -> Bool {
        guard !isPaid(instalment), let due = MeetingCal.day(from: instalment.dueDate) else { return false }
        return due < Calendar.current.startOfDay(for: Date())
    }

    private func label(_ instalment: Installment) -> (text: String, tint: Color) {
        if isPaid(instalment) { return ("Paid", .dealioStatusGreen) }
        if isOverdue(instalment) { return ("Overdue", .dealioError) }
        return ("Pending", .dealioStatusAmber)
    }

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
                    miniStat("Value", Money.inr(deal.dealValue), .dealioTextPrimary)
                    miniStat("Received", Money.inr(paid), .dealioStatusGreen)
                    miniStat("Pending", Money.inr(pending), .dealioStatusAmber)
                }
                if schedule.isEmpty {
                    Text("No demand letters recorded for this deal yet.").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(schedule) { instalment in
                        let state = label(instalment)
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(instalment.installment?.nilIfEmpty ?? "Installment")
                                    .font(.caption.weight(.semibold))
                                Text("\(Money.inr(instalment.amount)) · due \(Fmt.date(instalment.dueDate))")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusBadge(text: state.text, color: state.tint)
                        }
                        .padding(10)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
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
