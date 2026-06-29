import Foundation

// MARK: - Builder advanced-screen models
// Mirror the `/builder/:id/{meetings,commissions,loans,…}` DTOs. Optional where non-essential.

/// A site-visit request — `builder/:id/meetings`.
struct BuilderMeeting: Codable, Identifiable {
    let id: Int
    let customerName: String?
    let customerPhone: String?
    let status: String?
    let preferredDate: String?
    let preferredTime: String?
    let confirmedDate: String?
    let confirmedTime: String?
    let meetingType: String?

    var whenText: String {
        [confirmedDate ?? preferredDate, confirmedTime ?? preferredTime]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// A CP commission line — `builder/:id/commissions`.
struct Commission: Codable, Identifiable {
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
}
