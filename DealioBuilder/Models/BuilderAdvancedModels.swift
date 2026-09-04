import Foundation

// MARK: - Builder advanced-screen models
// Mirror the `/builder/:id/{meetings,commissions,loans,…}` DTOs. Optional where non-essential.

/// A site-visit request — `builder/:id/meetings`.
struct BuilderMeeting: Codable, Identifiable {
    let id: Int
    var customerName: String?
    var customerPhone: String?
    var projectName: String?
    var cpName: String?
    var status: String?
    var preferredDate: String?
    var preferredTime: String?
    var confirmedDate: String?
    var confirmedTime: String?
    var meetingType: String?
    var notes: String?

    var whenText: String {
        [confirmedDate ?? preferredDate, confirmedTime ?? preferredTime]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// A CP commission line — `builder/:id/commissions`.
/// `Hashable` so a commission row can be pushed by value from the list; `id` is
/// the deal the commission was derived from, and what release patches against.
struct Commission: Codable, Identifiable, Hashable {
    let id: String
    let projectName: String?
    let customerName: String?
    let saleValue: Double?
    let commissionPercent: Double?
    let amount: Double?
    let status: String?
    let releasedDate: String?
}

/// A home-loan case — `builder/:id/loans`.
struct BuilderLoan: Codable, Identifiable {
    let id: Int
    let projectName: String?
    let customerName: String?
    let loanAmount: Double?
    let tenureMonths: Int?
    let bank: String?
    let interestRate: Double?
    let emi: Double?
    let status: String?
}

/// A project document — `builder/:id/projects/:pid/documents`.
struct ProjectDocument: Codable, Identifiable {
    let id: Int
    let name: String?
    let url: String?
    let docType: String?
    let createdAt: String?

    var fileURL: URL? { AppConfig.resolveAssetURL(url) }

    // The documents endpoint responds with `fileName`/`fileUrl`/`uploadedAt`
    // (not `name`/`url`/`createdAt`) — accept both shapes.
    private enum CodingKeys: String, CodingKey {
        case id, name, url, docType, createdAt, fileName, fileUrl, uploadedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
            ?? c.decodeIfPresent(String.self, forKey: .fileName)
        url = try c.decodeIfPresent(String.self, forKey: .url)
            ?? c.decodeIfPresent(String.self, forKey: .fileUrl)
        docType = try c.decodeIfPresent(String.self, forKey: .docType)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
            ?? c.decodeIfPresent(String.self, forKey: .uploadedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encodeIfPresent(docType, forKey: .docType)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}
