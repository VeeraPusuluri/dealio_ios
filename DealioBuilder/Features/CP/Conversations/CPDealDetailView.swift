import SwiftUI

// MARK: - Conversations inbox

/// The channel partner's inbox — the shared person-to-person messaging screen,
/// told who is looking at it. See `ConversationsView`.
struct CPConversationsView: View {
    var body: some View {
        ConversationsView(
            viewer: .cp,
            emptyHint: "Refer a lead to start talking to the buyer and the builder."
        )
    }
}

// MARK: - Deal detail

/// One deal, as the partner works it.
///
/// The spine says where the deal is and whether it is waiting on this CP or on
/// someone else — this screen used to show only a raw status chip, so a partner
/// could not tell a deal that needed them from one that had been sitting with
/// the builder for a fortnight. Mirrors Android's `CpDealDetailScreen.kt`.

@MainActor
final class CPDealDetailModel: ObservableObject {
    @Published var deal: CpDealDetail?
    @Published var loading = true
    @Published var working = false
    @Published var error: String?
    @Published var message: String?

    private var cpUserId = 0
    private var dealId = 0

    func load(cpUserId: Int, dealId: Int, silent: Bool = false) async {
        self.cpUserId = cpUserId
        self.dealId = dealId
        if !silent { loading = deal == nil; error = nil }
        do { deal = try await CPService.deal(cpUserId: cpUserId, dealId: dealId) }
        catch { self.error = authMessage(error) }
        loading = false
    }

    private func refresh(_ success: String?) async {
        message = success
        await load(cpUserId: cpUserId, dealId: dealId, silent: true)
    }

    func agree() async {
        working = true
        defer { working = false }
        do {
            try await CPService.agreeToDeal(cpUserId: cpUserId, dealId: dealId)
            await refresh("Agreed — the builder and buyer have been told")
        } catch { message = authMessage(error) }
    }

    func nudge() async {
        working = true
        defer { working = false }
        do {
            _ = try await ThreadService.nudge(dealId: dealId)
            message = "Nudged. They'll see what the deal is waiting for."
        } catch { message = authMessage(error) }
    }

    func addFollowUp(dueDate: String, dueTime: String?, reason: String) async {
        working = true
        defer { working = false }
        do {
            try await CPService.createFollowUp(cpUserId: cpUserId, .init(
                dealId: dealId, dueDate: dueDate, dueTime: dueTime, reason: reason
            ))
            message = "Follow-up scheduled"
        } catch { message = authMessage(error) }
    }

    func logCall(outcome: String, duration: String, notes: String?) async {
        working = true
        defer { working = false }
        do {
            try await CPService.createCallLog(cpUserId: cpUserId, .init(
                dealId: dealId, outcome: outcome, duration: duration, notes: notes
            ))
            message = "Call logged"
        } catch { message = authMessage(error) }
    }

    /// Books a site visit on the buyer's behalf. The customer is fixed on a lead,
    /// so only the slot has to be chosen.
    func bookVisit(date: String, time: String, type: String) async {
        guard let deal, let builderId = deal.builderId else {
            message = "This deal has no builder attached yet."
            return
        }
        working = true
        defer { working = false }
        do {
            try await CPService.bookMeeting(.init(
                builderId: builderId, projectId: deal.projectId,
                customerName: deal.customerName, customerPhone: deal.customerPhone,
                preferredDate: date, preferredTime: time, meetingType: type, cpId: cpUserId
            ))
            await refresh("Visit requested — the builder will confirm a slot")
        } catch { message = authMessage(error) }
    }
}

struct CPDealDetailView: View {
    let dealId: Int
    var title: String = "Lead"

    @EnvironmentObject private var auth: AuthStore
    @Environment(\.openURL) private var openURL
    @StateObject private var model = CPDealDetailModel()

    @State private var showFollowUp = false
    @State private var showCallLog = false
    @State private var showBooking = false
    @State private var goConversations = false
    @State private var goEarnings = false

    /// When the baton is genuinely on the CP to agree, the spine owns that action
    /// — one primary CTA per screen. Everywhere else agreeing is still possible
    /// but demoted, because it is not what the deal is waiting for.
    private var ownsAgree: Bool {
        guard let deal = model.deal else { return false }
        return DealFlow.baton(deal.status, cpAgreed: deal.cpAgreed,
                              customerConfirmed: deal.customerConfirmed).heldBy(.cp)
            && !deal.cpAgreed
            && DealFlow.canonicalStage(deal.status) == "Agreement"
    }

    var body: some View {
        Group {
            if model.loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let deal = model.deal {
                content(deal)
            } else {
                VStack(spacing: 14) {
                    ErrorBanner(message: model.error ?? "Deal not found")
                    Button("Try again") { Task { await reload() } }.buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle(model.deal?.projectName.nilIfEmpty ?? title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .navigationDestination(isPresented: $goConversations) { CPConversationsView() }
        .navigationDestination(isPresented: $goEarnings) { CPEarningsView() }
        .sheet(isPresented: $showFollowUp) {
            DealFollowUpSheet(working: model.working) { date, time, reason in
                showFollowUp = false
                Task { await model.addFollowUp(dueDate: date, dueTime: time, reason: reason) }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showCallLog) {
            DealCallLogSheet(working: model.working) { outcome, duration, notes in
                showCallLog = false
                Task { await model.logCall(outcome: outcome, duration: duration, notes: notes) }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showBooking) {
            if let deal = model.deal {
                CPBookingSheet(projectName: deal.projectName,
                               customerName: deal.customerName,
                               customerPhone: deal.customerPhone,
                               working: model.working) { date, time, type in
                    showBooking = false
                    Task { await model.bookVisit(date: date, time: time, type: type) }
                }
                .presentationDetents([.medium, .large])
            }
        }
        .alert("Deal", isPresented: Binding(get: { model.message != nil },
                                            set: { if !$0 { model.message = nil } })) {
            Button("OK", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }

    private func reload() async {
        await model.load(cpUserId: auth.user?.id ?? 0, dealId: dealId)
    }

    @ViewBuilder
    private func content(_ deal: CpDealDetail) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                DealSpine(
                    rawStatus: deal.status,
                    viewer: .cp,
                    cpAgreed: deal.cpAgreed,
                    customerConfirmed: deal.customerConfirmed,
                    actionLabel: ownsAgree ? "Agree" : nil,
                    onAction: ownsAgree ? { Task { await model.agree() } } : nil,
                    onNudge: { Task { await model.nudge() } }
                )

                summaryCard(deal)

                StageActionCard(rawStatus: deal.status, viewer: .cp, enabled: !model.working) { target in
                    switch target {
                    case .requestVisit: showBooking = true
                    case .logFollowUp: showFollowUp = true
                    case .agree: Task { await model.agree() }
                    case .cpCommissions: goEarnings = true
                    default: break
                    }
                }

                if showEarlyAgree(deal) {
                    // Agreeing early is legitimate — the endpoint sets `cpAgreed`
                    // *and* moves the deal to Agreement — so this stays available,
                    // just not as a full-width primary competing with the spine.
                    outlineButton("Agree and move to Agreement", .brandTeal) {
                        Task { await model.agree() }
                    }
                }

                outlineButton("Message", .brandTeal, icon: "bubble.left") { goConversations = true }

                HStack(spacing: 10) {
                    outlineButton("Follow-up", .dealioNavy, icon: "calendar.badge.clock") { showFollowUp = true }
                    outlineButton("Log call", .dealioNavy, icon: "phone") { showCallLog = true }
                }

                if !deal.events.isEmpty {
                    ActivityLedger(events: deal.events)
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface()
                }
            }
            .padding(16)
        }
        .refreshable { await reload() }
    }

    /// Only while the deal has not yet reached Agreement. The endpoint behind
    /// this button *sets* the stage to Agreement, so on a booked deal it is not
    /// an early agreement — it is a button that drags a completed sale back into
    /// paperwork. An unrecognised stage withholds the shortcut rather than
    /// assuming the earliest one.
    private func showEarlyAgree(_ deal: CpDealDetail) -> Bool {
        guard !deal.cpAgreed, !ownsAgree else { return false }
        guard stageActionFor(deal.status, role: .cp).cta?.target != .agree else { return false }
        guard let stage = DealFlow.canonicalStage(deal.status),
              let index = DealFlow.stages.firstIndex(of: stage),
              let agreement = DealFlow.stages.firstIndex(of: "Agreement") else { return false }
        return index < agreement
    }

    private func summaryCard(_ deal: CpDealDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(deal.customerName.nilIfEmpty ?? "Customer")
                .font(.headline)
                .foregroundStyle(Color.dealioTextPrimary)
            InfoLine("Customer phone", deal.customerPhone.nilIfEmpty)
            InfoLine("Deal value", deal.dealValue.map { Money.inr($0) })
            InfoLine("Your commission", deal.commissionAmount.map {
                "\(Money.inr($0)) (\(Int(deal.commissionPercent ?? 0))%)"
            })
            InfoLine("Commission status", deal.commissionStatus)

            HStack(spacing: 8) {
                agreedPill("You", deal.cpAgreed)
                agreedPill("Customer", deal.customerConfirmed)
                Spacer()
                if !deal.customerPhone.isEmpty {
                    Button { if let url = Share.telURL(deal.customerPhone) { openURL(url) } } label: {
                        Image(systemName: "phone.fill").font(.caption).foregroundStyle(Color.brandTeal)
                            .frame(width: 30, height: 30)
                            .background(Color.brandTeal.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardSurface(cornerRadius: 16)
    }

    private func agreedPill(_ who: String, _ agreed: Bool) -> some View {
        Text("\(who): \(agreed ? "Agreed" : "Pending")")
            .font(.caption.weight(.semibold))
            .foregroundStyle(agreed ? Color.dealioStatusGreen : Color.dealioTextSecondary)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(agreed ? Color.dealioStatusGreenBg : Color.dealioFieldFill,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func outlineButton(_ title: String, _ tint: Color, icon: String? = nil,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let icon { Label(title, systemImage: icon) } else { Text(title) }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity).padding(.vertical, 13)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(tint.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(model.working)
    }
}

// MARK: - Sheets

private struct DealFollowUpSheet: View {
    let working: Bool
    let onSave: (String, String?, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var due = Date().addingTimeInterval(60 * 60 * 24)
    @State private var reason = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Due", selection: $due, displayedComponents: [.date, .hourAndMinute])
                TextField("Reason", text: $reason, axis: .vertical).lineLimit(1...3)
            }
            .navigationTitle("Schedule follow-up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schedule") {
                        guard let text = reason.trimmedOrNil else { return }
                        onSave(MeetupTime.wireDate(due), timeString(due), text)
                    }
                    .disabled(reason.trimmedOrNil == nil || working)
                }
            }
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}

private struct DealCallLogSheet: View {
    let working: Bool
    let onSave: (String, String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var outcome = outcomes[0]
    @State private var duration = durations[1]
    @State private var notes = ""

    private static let outcomes = ["Interested", "Call back later", "No answer",
                                   "Site visit booked", "Not interested"]
    private static let durations = ["1 min", "5 min", "10 min", "20 min", "30 min+"]

    var body: some View {
        NavigationStack {
            Form {
                Section("How it went") {
                    WrapPills(options: Self.outcomes, selection: outcome, accent: .brandTeal) { outcome = $0 }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    WrapPills(options: Self.durations, selection: duration, accent: .brandTeal) { duration = $0 }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                Section("Notes") {
                    TextField("What was said", text: $notes, axis: .vertical).lineLimit(2...5)
                }
            }
            .navigationTitle("Log a call")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(outcome, duration, notes.trimmedOrNil) }.disabled(working)
                }
            }
        }
    }
}

/// Booking a site visit for a buyer the partner already has.
///
/// The customer is fixed on a lead, so the sheet shows them rather than asking
/// the CP to type a name it already has.
struct CPBookingSheet: View {
    let projectName: String
    let customerName: String
    let customerPhone: String
    let working: Bool
    let onBook: (String, String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date = Date().addingTimeInterval(60 * 60 * 24)
    @State private var slot = slots[0]
    @State private var type = types[0]

    private static let slots = ["10:00 AM", "11:00 AM", "12:00 PM", "2:00 PM", "3:00 PM",
                                "4:00 PM", "5:00 PM", "6:00 PM"]
    private static let types = ["Site visit", "Office meeting", "Video call"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Who and where") {
                    InfoLine("Project", projectName)
                    InfoLine("Customer", customerName)
                    InfoLine("Phone", customerPhone.nilIfEmpty)
                }
                Section("When") {
                    DatePicker("Date", selection: $date, in: Date()..., displayedComponents: [.date])
                    WrapPills(options: Self.slots, selection: slot, accent: .brandTeal) { slot = $0 }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                Section("Kind of meeting") {
                    WrapPills(options: Self.types, selection: type, accent: .brandTeal) { type = $0 }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            .navigationTitle("Request a visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Request") { onBook(MeetupTime.wireDate(date), slot, type) }
                        .disabled(working)
                }
            }
        }
    }
}
