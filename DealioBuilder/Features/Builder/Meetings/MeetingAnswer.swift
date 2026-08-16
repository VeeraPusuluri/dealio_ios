import SwiftUI

/// The answers a builder can give a site-visit request.
///
/// A visit sat in the list read-only, so the one stage the whole pipeline waits
/// on — *Meeting Requested*, where the baton is squarely on the builder — had no
/// way to be answered from the app at all.
///
/// The wording is the web portal's, verbatim, so a builder who uses both reads
/// the same words in each.
enum MeetingAnswer: String, Identifiable, CaseIterable {
    case approve, reschedule, reject, complete, followUp, cancel

    var id: String { rawValue }

    /// What gets written to `Meeting.status`.
    var status: String {
        switch self {
        case .approve: return "Confirmed"
        case .reschedule: return "Rescheduled"
        case .reject, .cancel: return "Cancelled"
        case .complete: return "Completed"
        case .followUp: return "Follow-up Required"
        }
    }

    var label: String {
        switch self {
        case .approve: return "Approve Meeting"
        case .reschedule: return "Propose New Time"
        case .reject: return "Reject Request"
        case .complete: return "Mark as Completed"
        case .followUp: return "Flag Follow-up"
        case .cancel: return "Cancel Visit"
        }
    }

    var cta: String {
        switch self {
        case .approve: return "Approve"
        case .reschedule: return "Send new time"
        case .reject: return "Reject request"
        case .complete: return "Mark completed"
        case .followUp: return "Flag follow-up"
        case .cancel: return "Cancel visit"
        }
    }

    var done: String {
        switch self {
        case .approve: return "Visit confirmed"
        case .reschedule: return "New time proposed"
        case .reject: return "Request rejected"
        case .complete: return "Visit marked completed"
        case .followUp: return "Follow-up flagged"
        case .cancel: return "Visit cancelled"
        }
    }

    var systemImage: String {
        switch self {
        case .approve: return "checkmark.circle"
        case .reschedule: return "calendar"
        case .reject, .cancel: return "xmark.circle"
        case .complete: return "checkmark.seal"
        case .followUp: return "bubble.left"
        }
    }

    var tint: Color {
        switch self {
        case .approve: return .dealioTeal
        case .reschedule: return .dealioStatusAmber
        case .reject, .cancel: return .red
        case .complete: return .blue
        case .followUp: return .purple
        }
    }

    /// Filled and loud, or tinted and quiet. Only one answer per state is loud.
    var isPrimary: Bool { self == .approve || self == .complete }

    /// Approving and proposing both commit to a slot; the rest carry none.
    var needsSlot: Bool { self == .approve || self == .reschedule }

    var noteLabel: String {
        switch self {
        case .approve: return "Note for the customer (optional)"
        case .reschedule: return "Why the change (optional)"
        case .reject, .cancel: return "Reason (optional)"
        case .complete: return "Visit notes"
        case .followUp: return "What needs following up"
        }
    }

    var notePrompt: String {
        switch self {
        case .approve: return "e.g. Ask for Ravi at the site office."
        case .reschedule: return "e.g. The site is closed that morning."
        case .reject, .cancel: return "Shown to the customer and the channel partner."
        case .complete: return "e.g. Interested in Tower A, 15th floor. Wants a quote by Friday."
        case .followUp: return "e.g. Send the payment plan for the 3BHK."
        }
    }

    /// Which answers a visit is open to.
    ///
    /// A rescheduled visit keeps the same answers as a confirmed one: the
    /// builder has proposed a time and still has to be able to close it out
    /// afterwards. The web portal leaves that state with nothing to do, which is
    /// a gap there rather than a rule to copy.
    static func forStatus(_ status: String?) -> [MeetingAnswer] {
        switch (status ?? "Pending").lowercased() {
        case "pending": return [.approve, .reschedule, .reject]
        case "confirmed", "rescheduled": return [.complete, .followUp, .cancel]
        case "completed": return [.followUp]
        default: return []
        }
    }
}

/// Body for `PATCH builder/:id/meetings/:id`.
struct MeetingUpdateRequest: Encodable {
    let status: String
    let notes: String?
    let confirmedDate: String?
    let confirmedTime: String?
}

/// The sheet a builder answers a visit in: the slot, if the answer commits to
/// one, and a note that reaches the customer and the channel partner.
struct MeetingAnswerSheet: View {
    let meeting: BuilderMeeting
    let answer: MeetingAnswer
    let onSubmit: (_ date: String?, _ time: String?, _ notes: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var slot = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Customer", value: meeting.customerName ?? "Visitor")
                    if !meeting.whenText.isEmpty {
                        LabeledContent("Requested", value: meeting.whenText)
                    }
                }
                if answer.needsSlot {
                    Section(answer == .reschedule ? "New slot" : "Confirmed slot") {
                        DatePicker("Date", selection: $slot, displayedComponents: .date)
                        DatePicker("Time", selection: $slot, displayedComponents: .hourAndMinute)
                    }
                }
                Section(answer.noteLabel) {
                    TextField(answer.notePrompt, text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(answer.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(answer.cta) {
                        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSubmit(
                            answer.needsSlot ? Self.dateFormatter.string(from: slot) : nil,
                            answer.needsSlot ? Self.timeFormatter.string(from: slot) : nil,
                            trimmed.isEmpty ? nil : trimmed
                        )
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { slot = Self.preferredSlot(of: meeting) ?? Date() }
    }

    /// Opens on the slot the customer actually asked for, so approving as-is is
    /// one tap rather than a re-entry of a date already on the row.
    private static func preferredSlot(of meeting: BuilderMeeting) -> Date? {
        guard let date = meeting.confirmedDate ?? meeting.preferredDate else { return nil }
        let time = meeting.confirmedTime ?? meeting.preferredTime ?? "10:00"
        let combined = DateFormatter()
        combined.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd HH:mm", "yyyy-MM-dd hh:mm a"] {
            combined.dateFormat = format
            if let parsed = combined.date(from: "\(String(date.prefix(10))) \(time)") { return parsed }
        }
        combined.dateFormat = "yyyy-MM-dd"
        return combined.date(from: String(date.prefix(10)))
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "hh:mm a"
        return formatter
    }()
}
