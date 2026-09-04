import SwiftUI
import EventKit
import EventKitUI

/// The words a meetup is described in, shared by the organiser's screens and the
/// customer's.
///
/// Lives outside both the CP and customer folders because a category means the
/// same thing on either side — the moment one of them owns the vocabulary, the
/// other ends up importing across the app's main seam, or quietly forking it.
/// Mirrors Android's `ui/meetups/MeetupVocabulary.kt` and `MeetupUi.kt`.

/// What kind of gathering this is.
///
/// "Open house" and "Loan clinic" are different propositions, and someone
/// scanning a list sorts on that before they read the title. An unknown value
/// from a newer backend falls back to `other` rather than breaking a list, so
/// the two can be deployed in either order.
enum MeetupCategory: String, CaseIterable, Identifiable {
    case siteVisit = "SITE_VISIT"
    case openHouse = "OPEN_HOUSE"
    case investorEvening = "INVESTOR_EVENING"
    case nriSession = "NRI_SESSION"
    case loanClinic = "LOAN_CLINIC"
    case networking = "NETWORKING"
    case other = "OTHER"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .siteVisit: return "Site visit"
        case .openHouse: return "Open house"
        case .investorEvening: return "Investor evening"
        case .nriSession: return "NRI session"
        case .loanClinic: return "Loan clinic"
        case .networking: return "Networking"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .siteVisit: return "building.2"
        case .openHouse: return "house"
        case .investorEvening: return "chart.line.uptrend.xyaxis"
        case .nriSession: return "globe"
        case .loanClinic: return "building.columns"
        case .networking: return "hands.sparkles"
        case .other: return "person.3"
        }
    }

    var tint: Color {
        switch self {
        case .siteVisit: return .brandTeal
        case .openHouse: return .blue
        case .investorEvening: return .purple
        case .nriSession: return .orange
        case .loanClinic: return .green
        case .networking: return .red
        case .other: return .brandTeal
        }
    }

    /// The header wash behind an event with no photograph. A grey block reads as
    /// a broken image; a category-tinted gradient makes a list look deliberate,
    /// and tells you what each one is from across the room.
    var gradient: LinearGradient {
        LinearGradient(colors: [tint.opacity(0.92), tint.opacity(0.55)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func from(_ wire: String?) -> MeetupCategory {
        MeetupCategory(rawValue: wire ?? "") ?? .other
    }
}

/// In person, online, or both.
enum MeetupMode: String, CaseIterable, Identifiable {
    case inPerson = "IN_PERSON"
    case online = "ONLINE"
    case hybrid = "HYBRID"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .inPerson: return "In person"
        case .online: return "Online"
        case .hybrid: return "Both"
        }
    }

    static func from(_ wire: String?) -> MeetupMode {
        MeetupMode(rawValue: wire ?? "") ?? .inPerson
    }
}

/// How an answer reads, and the colour it carries, on both sides of the feature.
enum Rsvp: String, CaseIterable, Identifiable {
    case going = "GOING"
    case maybe = "MAYBE"
    case declined = "DECLINED"
    case invited = "INVITED"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .going: return "Going"
        case .maybe: return "Maybe"
        case .declined: return "Can't go"
        case .invited: return "No reply"
        }
    }
    var tint: Color {
        switch self {
        case .going: return .green
        case .maybe: return .orange
        case .declined: return .red
        case .invited: return Color(hex: 0x94A3B8)
        }
    }

    static func from(_ wire: String?) -> Rsvp { Rsvp(rawValue: wire ?? "") ?? .invited }
}

// MARK: - Time

enum MeetupTime {
    private static var posix: Locale { Locale(identifier: "en_US_POSIX") }

    private static func dayFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = posix
        formatter.dateFormat = format
        return formatter
    }

    /// Parses the stored `date` + `time` pair. The time half is free text as the
    /// organiser picked it ("04:00 PM"), so this tolerates both 12- and 24-hour
    /// shapes and falls back to midnight rather than failing the whole row.
    static func dateTime(date: String, time: String) -> Date? {
        guard let day = dayFormatter("yyyy-MM-dd").date(from: String(date.prefix(10))) else { return nil }
        guard let clock = parseTime(time) else { return day }
        return Calendar.current.date(bySettingHour: clock.hour, minute: clock.minute, second: 0, of: day) ?? day
    }

    private static func parseTime(_ raw: String) -> (hour: Int, minute: Int)? {
        let text = raw.trimmingCharacters(in: .whitespaces).uppercased()
        guard !text.isEmpty else { return nil }
        for format in ["hh:mm a", "h:mm a", "HH:mm"] {
            if let parsed = dayFormatter(format).date(from: text) {
                let parts = Calendar.current.dateComponents([.hour, .minute], from: parsed)
                return (parts.hour ?? 0, parts.minute ?? 0)
            }
        }
        return nil
    }

    /// "Saturday, 8 August 2026" — for the event page, where someone is deciding
    /// whether they can make it and wants the day and year spelled out.
    static func fullDate(_ date: String) -> String {
        guard let day = dayFormatter("yyyy-MM-dd").date(from: String(date.prefix(10))) else { return date }
        return dayFormatter("EEEE, d MMMM yyyy").string(from: day)
    }

    /// "Today", "Tomorrow", else "Fri, 8 Aug" — how a person says a near date.
    static func dayLabel(_ date: String) -> String {
        guard let day = dayFormatter("yyyy-MM-dd").date(from: String(date.prefix(10))) else { return date }
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return dayFormatter("EEE, d MMM").string(from: day)
    }

    /// The one-line "when": "Tomorrow · 04:00 PM".
    static func when(date: String, time: String) -> String {
        [dayLabel(date), time.trimmingCharacters(in: .whitespaces)]
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }

    static func isPast(_ date: String) -> Bool {
        guard let day = dayFormatter("yyyy-MM-dd").date(from: String(date.prefix(10))) else { return false }
        return Calendar.current.startOfDay(for: day) < Calendar.current.startOfDay(for: Date())
    }

    static func wireDate(_ date: Date) -> String { dayFormatter("yyyy-MM-dd").string(from: date) }
    /// The organiser-facing 12-hour form the backend stores verbatim.
    static func wireTime(_ date: Date) -> String { dayFormatter("hh:mm a").string(from: date) }
}

// MARK: - Calendar

/// Offers the meetup to the phone's calendar.
///
/// Presents the system event editor rather than writing directly: it lets the
/// user pick the account and confirm, which is what someone expects when an app
/// puts something in their diary. Two hours is assumed, since a meetup carries
/// no end time yet.
struct MeetupCalendarSheet: UIViewControllerRepresentable {
    let title: String
    let location: String
    let notes: String?
    let start: Date
    var onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = title
        event.location = location
        event.notes = notes
        event.startDate = start
        event.endDate = start.addingTimeInterval(2 * 60 * 60)
        event.calendar = store.defaultCalendarForNewEvents

        let controller = EKEventEditViewController()
        controller.event = event
        controller.eventStore = store
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func eventEditViewController(_ controller: EKEventEditViewController,
                                     didCompleteWith action: EKEventEditViewAction) {
            onFinish()
        }
    }
}
