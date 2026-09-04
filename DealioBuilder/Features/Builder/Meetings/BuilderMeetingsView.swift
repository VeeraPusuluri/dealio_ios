import SwiftUI

/// Site-visit requests, and the five answers a builder can give them.
///
/// The same answers the web portal offers, in the same words and the same order:
/// a builder who arranges visits on both should not have to work out that
/// "Mark rescheduled" here is "Propose New Time" there. Mirrors Android's
/// `ui/builder/meetings/MeetingsScreen.kt`.

// MARK: - The answers

/// Approving and proposing both commit to a slot; the rest carry none.
private struct MeetingAction: Identifiable {
    let status: String
    /// Label in the action list — the web portal's wording, verbatim.
    let label: String
    let title: String
    let cta: String
    let done: String
    let accent: Color
    let icon: String
    /// Filled and loud, or tinted and quiet. Only one action per state is loud.
    var filled = false
    var needsSlot = false
    let noteLabel: String
    let notePlaceholder: String

    var id: String { label }

    static let approve = MeetingAction(
        status: "Confirmed", label: "Approve Meeting", title: "Approve meeting",
        cta: "Approve", done: "Visit confirmed", accent: .brandTeal,
        icon: "checkmark.circle", filled: true, needsSlot: true,
        noteLabel: "Note for the customer (optional)",
        notePlaceholder: "e.g. Ask for Ravi at the site office."
    )
    static let reschedule = MeetingAction(
        status: "Rescheduled", label: "Propose New Time", title: "Propose new time",
        cta: "Send new time", done: "New time proposed", accent: .dealioStatusAmber,
        icon: "calendar", needsSlot: true,
        noteLabel: "Why the change (optional)",
        notePlaceholder: "e.g. The site is closed that morning."
    )
    static let reject = MeetingAction(
        status: "Cancelled", label: "Reject Request", title: "Reject request",
        cta: "Reject request", done: "Request rejected", accent: .dealioError,
        icon: "xmark.circle",
        noteLabel: "Reason (optional)",
        notePlaceholder: "Shown to the customer and the channel partner."
    )
    static let complete = MeetingAction(
        status: "Completed", label: "Mark as Completed", title: "Mark completed",
        cta: "Mark completed", done: "Visit marked completed", accent: .blue,
        icon: "checkmark.seal", filled: true,
        noteLabel: "Visit notes",
        notePlaceholder: "e.g. Interested in Tower A, 15th floor. Wants a quote by Friday."
    )
    static let followUp = MeetingAction(
        status: "Follow-up Required", label: "Flag Follow-up", title: "Flag follow-up",
        cta: "Flag follow-up", done: "Follow-up flagged", accent: .purple,
        icon: "bubble.left",
        noteLabel: "What needs following up",
        notePlaceholder: "e.g. Send the payment plan for the 3BHK."
    )
    static let cancel = MeetingAction(
        status: "Cancelled", label: "Cancel Visit", title: "Cancel visit",
        cta: "Cancel visit", done: "Visit cancelled", accent: .dealioError,
        icon: "xmark.circle",
        noteLabel: "Reason (optional)",
        notePlaceholder: "Shown to the customer and the channel partner."
    )

    /// Which answers a visit is open to.
    ///
    /// A rescheduled visit keeps the same answers as a confirmed one: the builder
    /// has proposed a time and still has to be able to close it out afterwards.
    static func forStatus(_ status: String?) -> [MeetingAction] {
        switch (status ?? "").lowercased() {
        case "pending": return [.approve, .reschedule, .reject]
        case "confirmed", "rescheduled": return [.complete, .followUp, .cancel]
        case "completed": return [.followUp]
        default: return []
        }
    }
}

// MARK: - Model

@MainActor
final class BuilderMeetingsModel: ObservableObject {
    @Published var all: [BuilderMeeting] = []
    @Published var filter = "All"
    @Published var loading = true
    @Published var working = false
    @Published var error: String?
    @Published var toast: String?

    let filters = ["All", "Pending", "Confirmed", "Completed"]

    private var builderId = 0

    var visible: [BuilderMeeting] {
        filter == "All" ? all : all.filter { ($0.status ?? "").caseInsensitiveCompare(filter) == .orderedSame }
    }
    func count(_ status: String) -> Int {
        all.filter { ($0.status ?? "").caseInsensitiveCompare(status) == .orderedSame }.count
    }

    func load(builderId: Int, silent: Bool = false) async {
        self.builderId = builderId
        if !silent { loading = all.isEmpty; error = nil }
        do { all = try await APIClient.shared.get("/builder/\(builderId)/meetings") }
        catch { self.error = authMessage(error) }
        loading = false
    }

    private struct UpdateRequest: Encodable {
        let status: String
        let notes: String?
        let confirmedDate: String?
        let confirmedTime: String?
    }

    /// Answer a visit request.
    ///
    /// `date` and `time` are the slot the builder is committing to — the one they
    /// approved, or the new one they are proposing. Approving with neither falls
    /// back to the slot the customer asked for, because a confirmation the
    /// customer reads as "confirmed for null at null" is worse than no answer;
    /// the other statuses carry no slot at all, so nothing is written over the
    /// one already on the row.
    func update(_ meeting: BuilderMeeting, status: String, date: String?, time: String?,
                notes: String?, done: String) async {
        working = true
        defer { working = false }
        let slotDate = date?.trimmedOrNil ?? (status == "Confirmed" ? meeting.preferredDate : nil)
        let slotTime = time?.trimmedOrNil ?? (status == "Confirmed" ? meeting.preferredTime : nil)
        do {
            try await APIClient.shared.patchVoid(
                "/builder/\(builderId)/meetings/\(meeting.id)",
                body: UpdateRequest(status: status, notes: notes?.trimmedOrNil,
                                    confirmedDate: slotDate, confirmedTime: slotTime)
            )
            toast = done
            await load(builderId: builderId, silent: true)
        } catch { toast = authMessage(error) }
    }
}

// MARK: - Screen

struct BuilderMeetingsView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.openURL) private var openURL
    @StateObject private var model = BuilderMeetingsModel()
    @State private var mode: MeetingViewMode = .list
    @State private var detail: BuilderMeeting?
    @State private var acting: ActingOn?

    private struct ActingOn: Identifiable {
        let meeting: BuilderMeeting
        let action: MeetingAction
        var id: String { "\(meeting.id)-\(action.label)" }
    }

    private var calendarMeetings: [CalMeeting] {
        model.all.compactMap { meeting in
            CalMeeting(id: "\(meeting.id)",
                       dateString: meeting.confirmedDate ?? meeting.preferredDate,
                       time: meeting.confirmedTime ?? meeting.preferredTime,
                       title: meeting.customerName ?? "Visitor",
                       subtitle: meeting.projectName,
                       status: meeting.status,
                       color: statusColor(meeting.status))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $mode) {
                ForEach(MeetingViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal).padding(.top, 8).padding(.bottom, 4)

            if mode == .list { filterChips }

            Group {
                if model.loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = model.error, model.all.isEmpty {
                    VStack(spacing: 14) {
                        ErrorBanner(message: error)
                        Button("Try again") { Task { await reload() } }.buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .padding()
                } else if mode == .calendar {
                    MeetingCalendarView(meetings: calendarMeetings)
                } else if model.visible.isEmpty {
                    ContentUnavailableView("No \(model.filter.lowercased()) site visits",
                        systemImage: "calendar",
                        description: Text("Visit requests from customers appear here."))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(model.visible) { meeting in
                                Button { detail = meeting } label: { card(meeting) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                    .refreshable { await reload() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.dealioMist.ignoresSafeArea())
        .navigationTitle("Site visits")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        // The detail sheet and the action form are one sheet at a time, not
        // stacked: two sheets open together fight over the scrim, and cancelling
        // the form should land back on the visit you were reading.
        .sheet(item: $detail) { meeting in
            MeetingDetailSheet(meeting: meeting, working: model.working) { action in
                detail = nil
                acting = ActingOn(meeting: meeting, action: action)
            } onCall: { phone in
                if let url = Share.telURL(phone) { openURL(url) }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $acting) { target in
            MeetingActionSheet(meeting: target.meeting, action: target.action, working: model.working) {
                date, time, notes in
                acting = nil
                Task {
                    await model.update(target.meeting, status: target.action.status,
                                       date: date, time: time, notes: notes, done: target.action.done)
                }
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Site visits", isPresented: Binding(get: { model.toast != nil },
                                                   set: { if !$0 { model.toast = nil } })) {
            Button("OK", role: .cancel) { model.toast = nil }
        } message: { Text(model.toast ?? "") }
    }

    private func reload() async {
        if let id = await auth.resolvedBuilderId() { await model.load(builderId: id) }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.filters, id: \.self) { option in
                    let selected = model.filter == option
                    let count = option == "All" ? model.all.count : model.count(option)
                    Button { withAnimation(.snappy) { model.filter = option } } label: {
                        Text(count > 0 ? "\(option) · \(count)" : option)
                            .font(.caption.weight(selected ? .semibold : .regular))
                            .foregroundStyle(selected ? .white : Color.dealioTextSecondary)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(selected ? Color.dealioNavyMid : Color(.secondarySystemGroupedBackground),
                                        in: Capsule())
                            .overlay(Capsule().strokeBorder(selected ? Color.dealioNavyMid : Color.dealioCardBorder,
                                                            lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 6)
        }
    }

    private func card(_ meeting: BuilderMeeting) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(meeting.customerName?.nilIfEmpty ?? "Visitor")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dealioTextPrimary)
                Spacer()
                StatusBadge(text: meeting.status ?? "Pending", color: statusColor(meeting.status))
            }
            if let project = meeting.projectName?.nilIfEmpty {
                Text(project).font(.caption).foregroundStyle(Color.dealioTextSecondary)
            }
            HStack(spacing: 10) {
                Label(meeting.whenText.nilIfEmpty ?? "No slot yet", systemImage: "clock")
                if let type = meeting.meetingType?.nilIfEmpty { Text("· \(type)") }
            }
            .font(.caption)
            .foregroundStyle(Color.dealioTextSecondary)

            if MeetingAction.forStatus(meeting.status).isEmpty == false {
                Text("Tap to answer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandTeal)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

// MARK: - Sheets

private struct MeetingDetailSheet: View {
    let meeting: BuilderMeeting
    let working: Bool
    let onPick: (MeetingAction) -> Void
    let onCall: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(meeting.customerName?.nilIfEmpty ?? "Visitor").font(.title3.weight(.bold))
                    StatusBadge(text: meeting.status ?? "Pending", color: statusColor(meeting.status))

                    VStack(spacing: 2) {
                        InfoLine("Project", meeting.projectName)
                        InfoLine("Requested", [meeting.preferredDate, meeting.preferredTime]
                            .compactMap { $0?.nilIfEmpty }.joined(separator: " · ").nilIfEmpty)
                        InfoLine("Confirmed", [meeting.confirmedDate, meeting.confirmedTime]
                            .compactMap { $0?.nilIfEmpty }.joined(separator: " · ").nilIfEmpty)
                        InfoLine("Type", meeting.meetingType)
                        InfoLine("Phone", meeting.customerPhone?.nilIfEmpty ?? "Contact via channel partner")
                        InfoLine("Channel partner", meeting.cpName ?? "Direct")
                        InfoLine("Notes", meeting.notes)
                    }

                    if let phone = meeting.customerPhone?.trimmedOrNil {
                        Button { onCall(phone) } label: {
                            Label("Call customer", systemImage: "phone")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.brandTeal, lineWidth: 1)
                                )
                                .foregroundStyle(Color.brandTeal)
                        }
                        .buttonStyle(.plain)
                    }

                    SectionLabel("Actions").padding(.top, 8)
                    let actions = MeetingAction.forStatus(meeting.status)
                    if actions.isEmpty {
                        Text("No further actions available.")
                            .font(.footnote)
                            .foregroundStyle(Color.dealioTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 10)
                    } else {
                        ForEach(actions) { action in
                            Button { onPick(action) } label: {
                                Label(action.label, systemImage: action.icon)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(action.filled ? .white : action.accent)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: action.filled ? 50 : 46)
                                    .background(action.filled ? AnyShapeStyle(LinearGradient.brand)
                                                              : AnyShapeStyle(action.accent.opacity(0.10)),
                                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(action.filled ? .clear : action.accent.opacity(0.35),
                                                          lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(working)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.dealioMist.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }
}

private struct MeetingActionSheet: View {
    let meeting: BuilderMeeting
    fileprivate let action: MeetingAction
    let working: Bool
    let onSubmit: (String?, String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var slot = ""
    @State private var notes = ""

    private static let slots = ["10:00 AM", "11:00 AM", "12:00 PM", "02:00 PM",
                                "03:00 PM", "04:00 PM", "05:00 PM", "06:00 PM"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meeting.customerName?.nilIfEmpty ?? "Visitor").font(.headline)
                        Text("Asked for \(meeting.whenText.nilIfEmpty ?? "no particular slot")")
                            .font(.caption).foregroundStyle(Color.dealioTextSecondary)
                    }
                }
                if action.needsSlot {
                    Section("The slot you're committing to") {
                        DatePicker("Date", selection: $date, in: Date()..., displayedComponents: [.date])
                        WrapPills(options: Self.slots, selection: slot, accent: action.accent) { slot = $0 }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
                Section(action.noteLabel) {
                    TextField(action.notePlaceholder, text: $notes, axis: .vertical).lineLimit(2...5)
                }
            }
            .navigationTitle(action.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action.cta) {
                        onSubmit(action.needsSlot ? MeetupTime.wireDate(date) : nil,
                                 action.needsSlot ? slot.nilIfEmpty : nil,
                                 notes.trimmedOrNil)
                    }
                    .disabled(working)
                }
            }
            .onAppear {
                // Approving defaults to the slot the buyer asked for; proposing a
                // new time deliberately starts blank so the builder has to choose.
                if action.status == "Confirmed" {
                    slot = meeting.preferredTime ?? ""
                    if let asked = MeetingCal.day(from: meeting.preferredDate) { date = asked }
                }
            }
        }
    }
}
