import Foundation

// MARK: - Customer portal domain models
// Mirror the backend `/customer` and `/portal/customer` DTOs. Unknown keys are
// ignored and all non-essential fields are optional so partial payloads decode.

/// A customer's deal/booking — the `portal/customer/deals` shape.
struct CustomerDeal: Codable, Identifiable {
    let dealId: Int
    var id: Int { dealId }
    let projectName: String?
    let dealStatus: String?
    let dealValue: Double?
    let createdAt: String?
    let loanStatus: String?
    let builderName: String?
    let cpName: String?
    let messages: [DealMessage]?
}

/// A site-visit / meeting — the `portal/customer/meetings` shape.
struct CustomerMeeting: Codable, Identifiable {
    let id: Int
    let projectName: String?
    let builderName: String?
    let status: String?
    let preferredDate: String?
    let preferredTime: String?
    let confirmedDate: String?
    let confirmedTime: String?

    var whenText: String {
        let date = confirmedDate ?? preferredDate
        let time = confirmedTime ?? preferredTime
        return [date, time].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// A shortlisted unit — the `portal/customer/shortlist` shape.
struct Shortlist: Codable, Identifiable {
    let id: Int
    let projectName: String?
    let unitId: String?
    let createdAt: String?
}

/// A channel partner available to assist a booking — `customer/cps`.
struct AvailableCP: Codable, Identifiable {
    let id: Int
    let fullName: String?
    let city: String?
    let tier: String?
}
