import SwiftUI

// MARK: - Customer portal domain models
// Mirror the backend `/customer` and `/portal/customer` DTOs. Unknown keys are
// ignored and all non-essential fields are optional so partial payloads decode.

/// A customer's deal/booking — the `portal/customer/deals` shape.
struct CustomerDeal: Codable, Identifiable {
    let dealId: Int
    var id: Int { dealId }
    var projectId: Int = 0
    var projectName: String = "Unknown Project"
    var builderName: String?
    var cpName: String?
    var dealStatus: String = ""
    var dealValue: Double?
    var customerConfirmed = false
    var cpAgreed = false
    var createdAt: String = ""
    var loanCaseId: Int?
    var loanAmount: Double?
    var loanStatus: String?
    var tenureMonths: Int?
    var interestRate: Double?
    var dealDocuments: [DealDocument] = []
    /// Only the legacy deal-scoped chat endpoint still sends these.
    var messages: [DealMessage]?

    private enum CodingKeys: String, CodingKey {
        case dealId, projectId, projectName, builderName, cpName, dealStatus, dealValue
        case customerConfirmed, cpAgreed, createdAt, loanCaseId, loanAmount, loanStatus
        case tenureMonths, interestRate, dealDocuments, messages
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dealId = try c.decode(Int.self, forKey: .dealId)
        projectId = try c.decodeIfPresent(Int.self, forKey: .projectId) ?? 0
        projectName = try c.decodeIfPresent(String.self, forKey: .projectName) ?? "Unknown Project"
        builderName = try c.decodeIfPresent(String.self, forKey: .builderName)
        cpName = try c.decodeIfPresent(String.self, forKey: .cpName)
        dealStatus = try c.decodeIfPresent(String.self, forKey: .dealStatus) ?? ""
        dealValue = try c.decodeIfPresent(Double.self, forKey: .dealValue)
        customerConfirmed = try c.decodeIfPresent(Bool.self, forKey: .customerConfirmed) ?? false
        cpAgreed = try c.decodeIfPresent(Bool.self, forKey: .cpAgreed) ?? false
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        loanCaseId = try c.decodeIfPresent(Int.self, forKey: .loanCaseId)
        loanAmount = try c.decodeIfPresent(Double.self, forKey: .loanAmount)
        loanStatus = try c.decodeIfPresent(String.self, forKey: .loanStatus)
        tenureMonths = try c.decodeIfPresent(Int.self, forKey: .tenureMonths)
        interestRate = try c.decodeIfPresent(Double.self, forKey: .interestRate)
        dealDocuments = try c.decodeIfPresent([DealDocument].self, forKey: .dealDocuments) ?? []
        messages = try c.decodeIfPresent([DealMessage].self, forKey: .messages)
    }
}

// MARK: - The buyer portal's palette
//
// The buyer portal ran on the shared brand teal, the same accent the builder and
// partner portals use, so the one portal a member of the public ever sees looked
// like the internal tooling it sits next to. It is now warm: gold on a sand
// field, which is the register property marketing is written in.

extension Color {
    /// The workhorse accent: link text, icons, selected states, thin rules.
    /// Deliberately *not* `customerAccentBright` — that gold on white carries
    /// about 2.3:1, which fails legibility for anything text-sized.
    static let customerAccent = Color(hex: 0xA9761F)
    /// Brand gold — fills, large surfaces, and anything sitting on navy.
    static let customerAccentBright = Color(hex: 0xC9A227)
    /// Pressed and depth states under `customerAccent`.
    static let customerAccentDeep = Color(hex: 0x7C5510)
    /// The page field behind the white cards — warm, where `dealioMist` is cool.
    static let customerSurface = Color(hex: 0xFAF8F3)
}

/// A site-visit / meeting — the `portal/customer/meetings` shape.
///
/// `projectAddress` / `projectCity` / the contact numbers are flattened onto the
/// row by `/builder/customer/meetings` only — the builder's and CP's own meeting
/// lists do not send them, so treat every one as absent unless proven otherwise.
struct CustomerMeeting: Codable, Identifiable {
    let id: Int
    var projectId: Int?
    var projectName: String?
    var builderName: String?
    var builderPhone: String?
    var cpName: String?
    var cpPhone: String?
    var status: String?
    var meetingType: String?
    var notes: String?
    var customerRating: Int?
    var preferredDate: String?
    var preferredTime: String?
    var confirmedDate: String?
    var confirmedTime: String?
    var projectAddress: String?
    var projectCity: String?

    var whenText: String {
        [confirmedDate ?? preferredDate, confirmedTime ?? preferredTime]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// A requested slot is not a booked one, and reading one as the other is how
    /// a buyer turns up to a locked gate.
    var isConfirmed: Bool { confirmedDate?.nilIfEmpty != nil }

    var whereLine: String? {
        [projectAddress, projectCity].compactMap { $0?.nilIfEmpty }
            .joined(separator: ", ").nilIfEmpty
    }
}

/// A shortlisted unit — the `portal/customer/shortlist` shape.
///
/// A shortlist is a unit the buyer *told a builder about*, which is what
/// separates it from a saved project: the builder has a queue of these to answer.
struct Shortlist: Codable, Identifiable {
    let id: Int
    var projectId: Int = 0
    var builderId: Int?
    var projectName: String?
    var unitId: String = ""
    var unitDetails: ShortlistUnitDetails?
    var status: String = "Pending"
    var builderNote: String?
    var createdAt: String?

    private enum CodingKeys: String, CodingKey {
        case id, projectId, builderId, projectName, unitId, unitDetails, status, builderNote, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        projectId = try c.decodeIfPresent(Int.self, forKey: .projectId) ?? 0
        builderId = try c.decodeIfPresent(Int.self, forKey: .builderId)
        projectName = try c.decodeIfPresent(String.self, forKey: .projectName)
        unitId = try c.decodeIfPresent(String.self, forKey: .unitId) ?? ""
        unitDetails = try c.decodeIfPresent(ShortlistUnitDetails.self, forKey: .unitDetails)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "Pending"
        builderNote = try c.decodeIfPresent(String.self, forKey: .builderNote)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

/// A channel partner available to assist a booking — `customer/cps`.
struct AvailableCP: Codable, Identifiable {
    let id: Int
    let fullName: String?
    let city: String?
    let tier: String?
}
