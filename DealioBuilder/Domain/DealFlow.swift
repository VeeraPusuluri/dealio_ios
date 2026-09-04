import SwiftUI

/// The deal flow, as all three parties see it.
///
/// The iOS mirror of the Android `ui/flow/DealFlow.kt`, which is itself the mirror
/// of `Dealio_Backend/src/utils/dealStage.ts`. All three must agree: the backend
/// validates writes against this ladder and the apps render against it.
///
/// Three things live here, and nothing else should re-derive them:
///   1. the canonical ten stages `Deal.status` may hold
///   2. the five phases a buyer sees, and the words they read
///   3. the baton — who owes the next move

// MARK: - The canonical ladder

enum DealFlow {
    static let stages = [
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
    /// the canonical ten. Rows written before the backend started validating are
    /// still in the database, so the app has to absorb them.
    private static let aliases: [String: String] = {
        var map = Dictionary(uniqueKeysWithValues: stages.map { ($0.lowercased(), $0) })
        let legacy = [
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
        map.merge(legacy) { current, _ in current }
        return map
    }()

    /// Fold a raw status onto the canonical ten, or nil when unrecognised.
    static func canonicalStage(_ raw: String?) -> String? {
        guard let key = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !key.isEmpty else { return nil }
        return aliases[key]
    }

    /// Position on the ladder; -1 when unrecognised.
    static func stageIndex(_ raw: String?) -> Int {
        guard let stage = canonicalStage(raw) else { return -1 }
        return stages.firstIndex(of: stage) ?? -1
    }

    // MARK: - The lead / deal line

    /// A lead and a deal are the same row at different points on the ladder, and
    /// the line between them is Negotiation — the point money enters the
    /// conversation. Mirrors `CONVERSION_STAGE` in `dealStage.ts`.
    static let conversionStage = "Negotiation"

    private static var conversionIndex: Int { stages.firstIndex(of: conversionStage) ?? 5 }

    /// True once the row has crossed into deal territory.
    static func isDealStage(_ raw: String?) -> Bool {
        let index = stageIndex(raw)
        return index >= 0 && index >= conversionIndex
    }

    /// True while the row is still a lead. The complement of `isDealStage`, not a
    /// range check, so an unrecognised status counts as a lead rather than
    /// vanishing from both screens.
    static func isLeadStage(_ raw: String?) -> Bool { !isDealStage(raw) }

    // MARK: - The buyer register

    private static let phaseOfStage: [String: JourneyPhase] = [
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

    /// The phase a buyer sees. Anything unrecognised reads as Enquiry.
    static func phase(_ rawStatus: String?) -> JourneyPhase {
        guard let stage = canonicalStage(rawStatus) else { return .enquiry }
        return phaseOfStage[stage] ?? .enquiry
    }

    /// What a buyer reads instead of the stage. Never contains pipeline vocabulary.
    static func buyerHeadline(_ rawStatus: String?) -> String {
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

    /// Who owes the next move on a deal. Derived, never stored — a pure function
    /// of the status plus the two agreement flags already on the row.
    static func baton(_ rawStatus: String?, cpAgreed: Bool = false, customerConfirmed: Bool = false) -> Baton {
        let stage = canonicalStage(rawStatus) ?? "New Lead"
        let spec = batonSpecs[stage] ?? batonSpecs["New Lead"]!
        // At Agreement each side is owed independently, so drop whoever has agreed.
        let holders: [DealRole] = stage == "Agreement"
            ? spec.holders.filter { $0 == .cp ? !cpAgreed : !customerConfirmed }
            : spec.holders
        return Baton(holders: holders, action: spec.action, buyerCopy: spec.buyerCopy)
    }

    private struct BatonSpec { let holders: [DealRole]; let action: String; let buyerCopy: String }

    private static let batonSpecs: [String: BatonSpec] = [
        "New Lead": .init(holders: [.cp], action: "Add the buyer's requirement", buyerCopy: "Your advisor is setting up your search"),
        "Profile Created": .init(holders: [.cp], action: "Request a site visit", buyerCopy: "Your advisor is arranging a visit"),
        "Meeting Requested": .init(holders: [.builder], action: "Confirm a site visit slot", buyerCopy: "The builder is confirming your slot"),
        "Meeting Confirmed": .init(holders: [.customer], action: "Attend the site visit", buyerCopy: "Your site visit is booked"),
        "Meeting Done": .init(holders: [.cp], action: "Capture feedback from the visit", buyerCopy: "Your advisor is following up"),
        "Negotiation": .init(holders: [.builder], action: "Send a pricing quote", buyerCopy: "The builder is preparing your quote"),
        "Agreement": .init(holders: [.cp, .customer], action: "Agree to the terms", buyerCopy: "Review and accept your agreement"),
        "Pending Booking": .init(holders: [.customer], action: "Complete the booking payment", buyerCopy: "Complete your booking payment"),
        "Booked": .init(holders: [.builder], action: "Registration and possession", buyerCopy: "The builder is preparing registration"),
        "Closed": .init(holders: [], action: "Complete", buyerCopy: "Complete"),
    ]

    /// Past this, a waiting deal is stalled. Mirrors the admin surface's `STALE_LEAD_DAYS`.
    static let stalledAfterDays = 14
}

// MARK: - Supporting types

enum JourneyPhase: Int, CaseIterable, Identifiable {
    case enquiry, visit, deal, booking, handover

    var id: Int { rawValue }
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

enum DealRole: String, CaseIterable, Identifiable {
    case builder, cp, customer

    var id: String { rawValue }

    /// Prose, and it changes with the register the reader is in.
    var label: String {
        switch self {
        case .builder: return "Builder"
        case .cp: return "your advisor"
        case .customer: return "Customer"
        }
    }

    /// What the backend calls this role — on a message's `senderRole`, and in the
    /// hyphenated conversation kinds ("builder-cp", "cp-customer"). Distinct from
    /// `label`; comparing against the label is what this exists to prevent.
    var wireName: String { rawValue }

    /// Role colour identifies people, never actions — CTAs keep the app accent.
    var color: Color {
        switch self {
        case .builder: return .dealioNavy
        case .cp: return .brandTeal
        case .customer: return .dealioOrange
        }
    }

    /// The viewer role for an auth role string ("BUILDER" / "CP" / "CUSTOMER").
    static func from(authRole: String?) -> DealRole {
        switch (authRole ?? "").uppercased() {
        case "BUILDER": return .builder
        case "CP": return .cp
        default: return .customer
        }
    }
}

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
