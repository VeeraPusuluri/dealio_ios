import SwiftUI

/// One deal, as the builder works it.
///
/// The spine says who the deal is waiting on; the stage card says what the
/// builder may do about it; the Advance block is the manual override. Messaging
/// is one tap away rather than embedded — the buyer and the partner on this deal
/// are the same people on every other one, and there is one conversation with
/// each of them. Mirrors Android's `ui/builder/deals/DealDetailScreen.kt`.

@MainActor
final class BuilderDealDetailModel: ObservableObject {
    @Published var deal: DealDetail?
    @Published var loading = true
    @Published var error: String?
    @Published var working = false
    @Published var toast: String?

    private var builderId = 0
    private var dealId = 0

    func load(builderId: Int, dealId: Int) async {
        self.builderId = builderId
        self.dealId = dealId
        loading = deal == nil
        error = nil
        do { deal = try await APIClient.shared.get("/builder/\(builderId)/deals/\(dealId)") }
        catch { self.error = authMessage(error) }
        loading = false
    }

    private func refresh() async { await load(builderId: builderId, dealId: dealId) }

    /// Nudge whoever the deal is waiting on; the cooldown reply is worth showing.
    func nudge() async {
        working = true
        defer { working = false }
        do {
            _ = try await ThreadService.nudge(dealId: dealId)
            toast = "Nudged. They'll see what the deal is waiting for."
        } catch { toast = authMessage(error) }
    }

    func updateStatus(_ status: String) async {
        struct Body: Encodable { let status: String }
        working = true
        defer { working = false }
        do {
            try await APIClient.shared.patchVoid("/builder/\(builderId)/deals/\(dealId)/status",
                                                 body: Body(status: status))
            toast = "Moved to \(status)"
            await refresh()
        } catch { toast = authMessage(error) }
    }

    /// Countersign the signed agreement.
    ///
    /// Deliberately not `updateStatus("Pending Booking")`: that route moves the
    /// deal whether or not the buyer ever sent a signed copy, and does not tell
    /// the CP or the buyer that it was accepted. The 400 this can return — "no
    /// signed agreement has been submitted yet" — is the answer, so it is
    /// surfaced rather than swallowed.
    func acceptAgreement() async {
        working = true
        defer { working = false }
        do {
            try await APIClient.shared.patchVoid("/builder/\(builderId)/deals/\(dealId)/accept-agreement")
            toast = "Agreement accepted"
            await refresh()
        } catch { toast = authMessage(error) }
    }

    func markSold() async {
        working = true
        defer { working = false }
        do {
            try await APIClient.shared.patchVoid("/builder/\(builderId)/deals/\(dealId)/mark-sold")
            toast = "Unit marked sold"
            await refresh()
        } catch { toast = authMessage(error) }
    }
}

struct BuilderDealDetailView: View {
    let dealId: Int
    var title: String = "Deal"

    @EnvironmentObject private var auth: AuthStore
    @Environment(\.openURL) private var openURL
    @StateObject private var model = BuilderDealDetailModel()

    var body: some View {
        Group {
            if model.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.error, model.deal == nil {
                VStack(spacing: 14) {
                    ErrorBanner(message: error)
                    Button("Try again") { Task { await reload() } }.buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding()
            } else if let deal = model.deal {
                ScrollView {
                    VStack(spacing: 12) {
                        header(deal)

                        DealSpine(
                            rawStatus: deal.status,
                            viewer: .builder,
                            cpAgreed: deal.cpAgreed,
                            customerConfirmed: deal.customerConfirmed,
                            onNudge: { Task { await model.nudge() } }
                        )

                        // What the builder may do at this stage, from the table
                        // all three portals read. It matters most around the
                        // visit: the slot the CP is waiting on is confirmed on
                        // the meetings screen, and nothing here said so.
                        StageActionCard(rawStatus: deal.status, viewer: .builder,
                                        enabled: !model.working) { target in
                            handle(target)
                        }
                        .background(stageNavigation)

                        advanceCard(deal)
                        partiesCard(deal)
                        commissionCard(deal)
                        if let schedule = deal.paymentSchedule, !schedule.isEmpty {
                            paymentCard(schedule)
                        }
                        documentsCard(deal)
                        if !deal.events.isEmpty {
                            ActivityLedger(events: deal.events)
                                .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
                        }

                        NavigationLink { BuilderConversationsView() } label: {
                            Label("Message", systemImage: "bubble.left")
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 13)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.brandTeal, lineWidth: 1)
                                )
                                .foregroundStyle(Color.brandTeal)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                }
                .refreshable { await reload() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle(model.deal?.customerName.nilIfEmpty ?? title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .alert("Deal", isPresented: Binding(get: { model.toast != nil },
                                            set: { if !$0 { model.toast = nil } })) {
            Button("OK", role: .cancel) { model.toast = nil }
        } message: { Text(model.toast ?? "") }
        .navigationDestination(isPresented: $goMeetings) { BuilderMeetingsView() }
        .navigationDestination(isPresented: $goShortlists) { BuilderShortlistsView() }
        .navigationDestination(isPresented: $goCommissions) { BuilderCommissionsView() }
    }

    @State private var goMeetings = false
    @State private var goShortlists = false
    @State private var goCommissions = false

    /// Keeps the three stage-CTA destinations attached to the card without
    /// nesting `navigationDestination` inside a conditional.
    private var stageNavigation: some View { Color.clear }

    private func handle(_ target: StageTarget) {
        switch target {
        case .builderMeetings: goMeetings = true
        case .builderShortlists: goShortlists = true
        case .builderCommissions: goCommissions = true
        case .builderAcceptAgreement: Task { await model.acceptAgreement() }
        default: break
        }
    }

    private func reload() async {
        if let id = await auth.resolvedBuilderId() { await model.load(builderId: id, dealId: dealId) }
    }

    // MARK: Cards

    private func header(_ deal: DealDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(deal.customerName.nilIfEmpty ?? "Customer")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.dealioTextPrimary)
                Text(deal.projectName.nilIfEmpty ?? "—")
                    .font(.footnote)
                    .foregroundStyle(Color.dealioTextSecondary)
            }
            if (deal.dealValue ?? 0) > 0 {
                Text("Deal value \(Money.inr(deal.dealValue))")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.brandTeal)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func advanceCard(_ deal: DealDetail) -> some View {
        // When the stage card above already offers the proper move for this
        // stage, the generic advance is not a second way to do it — it is a way
        // to do it *without* the checks that move carries.
        let stageOwnsAdvance = stageActionFor(deal.status, role: .builder).cta?.target == .builderAcceptAgreement
        let index = DealFlow.stageIndex(deal.status)
        let next = (index >= 0 && index < DealFlow.stages.count - 1) ? DealFlow.stages[index + 1] : nil
        let canMarkSold = ["pending booking", "booked"].contains(deal.status.lowercased())

        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Advance")
            if stageOwnsAdvance {
                Text("Countersign the agreement above to move this deal on.")
                    .font(.footnote).foregroundStyle(Color.dealioTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let next {
                actionButton("Advance to \(next)", .dealioNavy) { Task { await model.updateStatus(next) } }
            } else {
                Text("This deal is complete.").font(.footnote).foregroundStyle(Color.dealioTextSecondary)
            }
            if canMarkSold {
                actionButton("Mark unit SOLD", .dealioStatusGreen) { Task { await model.markSold() } }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func partiesCard(_ deal: DealDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Parties")
            InfoLine("Customer", deal.customerName)
            InfoLine("Phone", deal.customerPhone.nilIfEmpty ?? "Contact via channel partner")
            InfoLine("Channel partner", deal.cpName ?? "Direct")
            InfoLine("CP phone", deal.cpPhone)
            InfoLine("CP tier", deal.cpTier)
            if !deal.customerPhone.isEmpty {
                Button {
                    if let url = Share.telURL(deal.customerPhone) { openURL(url) }
                } label: {
                    Label("Call customer", systemImage: "phone")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.brandTeal, lineWidth: 1)
                        )
                        .foregroundStyle(Color.brandTeal)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func commissionCard(_ deal: DealDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Commission")
            InfoLine("Rate", deal.commissionPercent.map { "\(Int($0))%" })
            InfoLine("Amount", deal.commissionAmount.map { Money.inr($0) })
            InfoLine("Status", deal.commissionStatus)
            InfoLine("CP agreed", deal.cpAgreed ? "Yes" : "No")
            InfoLine("Customer confirmed", deal.customerConfirmed ? "Yes" : "No")
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func paymentCard(_ schedule: [Installment]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Payment schedule")
            ForEach(schedule) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.installment ?? "Installment")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.dealioTextPrimary)
                        if let due = item.dueDate, !due.isEmpty {
                            Text(String(due.prefix(10)))
                                .font(.caption2).foregroundStyle(Color.dealioTextSecondary)
                        }
                    }
                    Spacer()
                    Text(Money.inr(item.amount))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.dealioTextPrimary)
                    StatusBadge(text: item.status ?? "Pending", color: statusColor(item.status))
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func documentsCard(_ deal: DealDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Documents (\(deal.dealDocuments.count))")
            if deal.dealDocuments.isEmpty {
                Text("No documents shared yet.").font(.footnote).foregroundStyle(Color.dealioTextSecondary)
            } else {
                ForEach(deal.dealDocuments) { doc in
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text").foregroundStyle(Color.brandTeal)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(doc.name.nilIfEmpty ?? doc.docType)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Color.dealioTextPrimary)
                            Text(doc.docType).font(.caption2).foregroundStyle(Color.dealioTextSecondary)
                        }
                        Spacer()
                        if doc.sharedWithCustomer { StatusBadge(text: "Customer", color: .brandTeal) }
                        if doc.sharedWithCp { StatusBadge(text: "CP", color: .indigo) }
                    }
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                    .onTapGesture { if let url = doc.fileURL { openURL(url) } }
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
    }

    private func actionButton(_ title: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(model.working ? tint.opacity(0.5) : tint,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(model.working)
    }
}

// MARK: - Small building blocks shared by the deal screens

/// An all-caps section label, the header every detail card opens with.
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9.5, weight: .black))
            .tracking(0.7)
            .foregroundStyle(Color.dealioTextSecondary)
    }
}

/// A label/value line that hides itself when there is no value — so a card never
/// shows a row of dashes for fields the backend didn't send.
struct InfoLine: View {
    let label: String
    let value: String?

    init(_ label: String, _ value: String?) { self.label = label; self.value = value }

    var body: some View {
        if let value, !value.isEmpty {
            HStack(alignment: .top) {
                Text(label).font(.footnote).foregroundStyle(Color.dealioTextSecondary)
                Spacer(minLength: 12)
                Text(value)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.dealioTextPrimary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 1)
        }
    }
}
