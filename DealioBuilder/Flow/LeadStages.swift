import Foundation

/// The columns on the lead board — the ladder up to the conversion point, not
/// the whole of it.
///
/// Derived from the canonical ladder rather than hand-listed, so the board and
/// the deal screens cannot disagree about where a row sits. Everything from
/// Negotiation on is a deal and lives on the Deals screen; the server no longer
/// returns those rows from `/leads`, so keeping their columns here would render
/// five that can never fill.
let LEAD_STAGES = DEAL_STAGES.filter { isLeadStage($0) }

/// Allowed forward transitions from each stage.
let NEXT_STAGES: [String: [String]] = [
    "New Lead": ["Profile Created", "Meeting Requested", "Negotiation", "Closed"],
    "Profile Created": ["Meeting Requested", "Negotiation", "Closed"],
    "Meeting Requested": ["Meeting Confirmed", "Meeting Done", "Negotiation", "Closed"],
    "Meeting Confirmed": ["Meeting Done", "Negotiation", "Closed"],
    "Meeting Done": ["Negotiation", "Agreement", "Booked", "Closed"],
    "Negotiation": ["Agreement", "Booked", "Closed"],
    "Agreement": ["Pending Booking", "Booked", "Closed"],
    "Pending Booking": ["Booked", "Closed"],
    "Booked": ["Closed"],
    "Closed": [],
]

/// A raw `stage` off the wire, folded onto the canonical ten.
///
/// The enum spellings arrive underscored (`MEETING_REQUESTED`), which the shared
/// alias table does not carry, so they are unpicked to words first. Anything the
/// ladder still doesn't recognise is returned untouched — the baton grouping
/// gathers those into their own section rather than guessing a stage for them.
func stageLabel(_ raw: String?) -> String {
    guard let raw, !raw.isEmpty else { return "New Lead" }
    return canonicalStage(raw.replacingOccurrences(of: "_", with: " ")) ?? raw
}

/// The value `PATCH /builder/:builderId/leads/:dealId/stage` expects — the
/// canonical spaced label, unchanged.
///
/// Not SCREAMING_CASE: the API keys on the spaced labels, and translating to
/// `MEETING_REQUESTED` is what made four of the ten stages come back
/// `400 Unknown stage` on Android until it was fixed there.
func stageWireValue(_ label: String) -> String { label }

/// How the pipeline is cut: by where a lead is, or by who owes its next move.
enum PipelineGrouping: String, CaseIterable, Identifiable {
    case stage = "By stage"
    case baton = "By who's next"
    var id: String { rawValue }
}

/// The buckets the baton grouping offers, in the order a builder should read them.
///
/// `complete` is a real answer (nobody owes anything), and `unknown` collects
/// rows whose stage isn't on the canonical ladder — surfacing them rather than
/// filing them under a guess, since a status the app doesn't recognise is a data
/// problem worth seeing.
enum BatonGroup: String, CaseIterable, Identifiable {
    case builder, cp, customer, complete, unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .builder: return "Yours"
        case .cp: return "Waiting on the partner"
        case .customer: return "Waiting on the buyer"
        case .complete: return "Nothing owed"
        case .unknown: return "Unrecognised stage"
        }
    }

    /// The bucket a raw stage falls in.
    ///
    /// A lead lands in one bucket — its first holder — even at Agreement, where
    /// the partner and the buyer are owed independently; the row says so. The
    /// agreement flags aren't on the leads payload, so neither side can be
    /// struck off here the way the deal room strikes them off.
    static func of(_ rawStage: String?) -> BatonGroup {
        guard canonicalStage(rawStage) != nil else { return .unknown }
        guard let holder = batonOf(rawStage).holders.first else { return .complete }
        switch holder {
        case .builder: return .builder
        case .cp: return .cp
        case .customer: return .customer
        }
    }
}
