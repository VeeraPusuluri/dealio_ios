import Foundation

/// The deal flow, as all three parties see it.
///
/// This is the iOS mirror of `Dealio_Backend/src/utils/dealStage.ts` and of the
/// Android app's `ui/flow/DealFlow.kt`. All three must agree: the backend
/// validates writes against this ladder, and the apps render against it. Change
/// one, change the others.
///
/// Three things live here, and nothing else should re-derive them:
///   1. the canonical ten stages `Deal.status` may hold
///   2. the five phases a buyer sees, and the words they read
///   3. the baton — who owes the next move

// MARK: - The canonical ladder

let DEAL_STAGES = [
    "New Lead",
    "Profile Created",
    "Meeting Requested",
    "Meeting Confirmed",
    "Meeting Done",
    "Negotiation",
    "Agreement",
    "Pending Booking",
    "Booked",
    "Closed",
]

/// Every legacy or coined spelling ever written to `Deal.status`, folded onto
/// the canonical ten.
///
/// Rows written before the backend started validating are still in the database,
/// so the app has to absorb them. Loan sub-stages land on Booked (booking is when
/// money moved); registration and both spellings of possession land on Closed.
private let STAGE_ALIASES: [String: String] = {
    var map = Dictionary(uniqueKeysWithValues: DEAL_STAGES.map { ($0.lowercased(), $0) })
    let extras = [
        "enquiry": "New Lead",
        "lead": "New Lead",
        "interested loan required": "Negotiation",
        "interested - loan required": "Negotiation",
        "site visit scheduled": "Meeting Confirmed",
        "site visit done": "Meeting Done",
        "meeting completed": "Meeting Done",
        "loan application created": "Booked",
        "loan applied": "Booked",
        "loan processing": "Booked",
        "loan sanctioned": "Booked",
        "loan disbursed": "Booked",
        "registration done": "Closed",
        "possession": "Closed",
        "possession given": "Closed",
        "won": "Closed",
    ]
    map.merge(extras) { current, _ in current }
    return map
}()

/// Folds a raw status onto the canonical ten, or `nil` when unrecognised.
func canonicalStage(_ raw: String?) -> String? {
    guard let key = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !key.isEmpty
    else { return nil }
    return STAGE_ALIASES[key]
}

/// Position on the ladder; `-1` when unrecognised.
func stageIndex(_ raw: String?) -> Int {
    guard let stage = canonicalStage(raw) else { return -1 }
    return DEAL_STAGES.firstIndex(of: stage) ?? -1
}

// MARK: - The lead / deal line

/// A lead and a deal are the same row at different points on the ladder, and the
/// line between them is Negotiation — the point money enters the conversation.
///
/// This mirrors `CONVERSION_STAGE` in `dealStage.ts`. The server already
/// partitions `/leads` and `/deals` on it, so filtering again here is
/// belt-and-braces rather than the primary defence — but it is what keeps a
/// screen honest when it holds a mixed list from some other endpoint (the CP has
/// one `/leads` call that still returns both sides of the line).
let CONVERSION_STAGE = "Negotiation"

private let CONVERSION_INDEX = DEAL_STAGES.firstIndex(of: CONVERSION_STAGE) ?? 5

/// True once the row has crossed into deal territory.
func isDealStage(_ raw: String?) -> Bool {
    let index = stageIndex(raw)
    return index >= 0 && index >= CONVERSION_INDEX
}

/// True while the row is still a lead.
///
/// The complement of `isDealStage`, not a range check, so an unrecognised status
/// counts as a lead. A row matching neither would vanish from both screens,
/// which is worse than the duplication this replaced.
func isLeadStage(_ raw: String?) -> Bool { !isDealStage(raw) }

// MARK: - The buyer register

enum JourneyPhase: Int, CaseIterable {
    case enquiry, visit, deal, booking, handover

    var label: String {
        switch self {
        case .enquiry: return "Enquiry"
        case .visit: return "Visit"
        case .deal: return "Deal"
        case .booking: return "Booking"
        case .handover: return "Handover"
        }
    }
}

private let PHASE_OF: [String: JourneyPhase] = [
    "New Lead": .enquiry,
    "Profile Created": .enquiry,
    "Meeting Requested": .visit,
    "Meeting Confirmed": .visit,
    "Meeting Done": .visit,
    "Negotiation": .deal,
    "Agreement": .deal,
    "Pending Booking": .booking,
    "Booked": .booking,
    "Closed": .handover,
]

/// The phase a buyer sees. An unknown status opens at Enquiry rather than
/// falling off the track.
func phaseOf(_ rawStatus: String?) -> JourneyPhase {
    guard let stage = canonicalStage(rawStatus) else { return .enquiry }
    return PHASE_OF[stage] ?? .enquiry
}

/// What a buyer reads instead of the stage. Never contains pipeline vocabulary.
func buyerHeadline(_ rawStatus: String?) -> String {
    switch canonicalStage(rawStatus) {
    case "New Lead": return "We have your enquiry"
    case "Profile Created": return "We have your requirement"
    case "Meeting Requested": return "We are arranging your site visit"
    case "Meeting Confirmed": return "Your site visit is confirmed"
    case "Meeting Done": return "Thanks for visiting"
    case "Negotiation": return "Your price quote is being prepared"
    case "Agreement": return "Your agreement is ready to review"
    case "Pending Booking": return "Your booking is being held"
    case "Booked": return "Your home is booked"
    case "Closed": return "Registration and handover"
    default: return "We have your enquiry"
    }
}

// MARK: - The baton

enum DealRole: String, CaseIterable {
    case builder = "BUILDER"
    case cp = "CP"
    case customer = "CUSTOMER"

    var label: String {
        switch self {
        case .builder: return "Builder"
        case .cp: return "your advisor"
        case .customer: return "Customer"
        }
    }
}

/// Who owes the next move on a deal.
///
/// Derived, never stored — a pure function of the status plus the two agreement
/// flags already on the row. That is what lets this ship without a schema change.
struct Baton {
    /// Who owes the move. Empty once the deal is closed.
    let holders: [DealRole]
    /// Imperative, addressed to whoever holds it.
    let action: String
    /// Buyer-safe phrasing of the same wait.
    let buyerCopy: String

    func heldBy(_ role: DealRole) -> Bool { holders.contains(role) }
    var isComplete: Bool { holders.isEmpty }
}

private struct BatonSpec {
    let holders: [DealRole]
    let action: String
    let buyerCopy: String
}

private let BATON_OF: [String: BatonSpec] = [
    "New Lead": .init(holders: [.cp], action: "Add the buyer's requirement",
                      buyerCopy: "Your advisor is setting up your search"),
    "Profile Created": .init(holders: [.cp], action: "Request a site visit",
                             buyerCopy: "Your advisor is arranging a visit"),
    "Meeting Requested": .init(holders: [.builder], action: "Confirm a site visit slot",
                               buyerCopy: "The builder is confirming your slot"),
    "Meeting Confirmed": .init(holders: [.customer], action: "Attend the site visit",
                               buyerCopy: "Your site visit is booked"),
    "Meeting Done": .init(holders: [.cp], action: "Capture feedback from the visit",
                          buyerCopy: "Your advisor is following up"),
    "Negotiation": .init(holders: [.builder], action: "Send a pricing quote",
                         buyerCopy: "The builder is preparing your quote"),
    "Agreement": .init(holders: [.cp, .customer], action: "Agree to the terms",
                       buyerCopy: "Review and accept your agreement"),
    "Pending Booking": .init(holders: [.customer], action: "Complete the booking payment",
                             buyerCopy: "Complete your booking payment"),
    "Booked": .init(holders: [.builder], action: "Registration and possession",
                    buyerCopy: "The builder is preparing registration"),
    "Closed": .init(holders: [], action: "Complete", buyerCopy: "Complete"),
]

func batonOf(_ rawStatus: String?, cpAgreed: Bool = false, customerConfirmed: Bool = false) -> Baton {
    let stage = canonicalStage(rawStatus) ?? "New Lead"
    let spec = BATON_OF[stage] ?? BATON_OF["New Lead"]!
    // At Agreement each side is owed independently, so drop whoever has agreed.
    let holders: [DealRole]
    if stage == "Agreement" {
        holders = spec.holders.filter { $0 == .cp ? !cpAgreed : !customerConfirmed }
    } else {
        holders = spec.holders
    }
    return Baton(holders: holders, action: spec.action, buyerCopy: spec.buyerCopy)
}

/// Past this, a waiting deal is stalled. Mirrors the admin surface's
/// `STALE_LEAD_DAYS`.
let STALLED_AFTER_DAYS = 14

/// Whole days between an ISO-8601 timestamp and now, or `nil` if unparseable.
///
/// Only the date part is used — staleness is counted in days, and a deal touched
/// this morning versus last night is the same answer.
func daysSince(_ iso: String?) -> Int? {
    guard let iso, iso.count >= 10 else { return nil }
    let datePart = String(iso.prefix(10))
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    guard let then = formatter.date(from: datePart) else { return nil }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let today = calendar.startOfDay(for: Date())
    let days = calendar.dateComponents([.day], from: then, to: today).day
    return days.map { max(0, $0) }
}
