import Foundation

// MARK: - Channel-partner domain models
// Mirror the backend `/cp/:cpUserId/...` DTOs. Non-essential fields optional.

/// A lead referred by this CP — `cp/:id/leads`.
struct CpLead: Codable, Identifiable {
    let id: Int
    let projectName: String?
    let customerName: String?
    let customerPhone: String?
    let status: String?
    let dealValue: Double?
    let estimatedCommission: Double?
    let createdAt: String?
}

/// A commission line — `cp/:id/commissions`.
struct CpCommission: Codable, Identifiable {
    let id: Int
    let status: String?
    let commissionStatus: String?
    let commissionAmount: Double?
    let commissionPercent: Double?
    let customerName: String?
    let projectName: String?
}

/// The CP's profile + verification/earnings summary — `cp/:id/profile`.
struct CpProfile: Codable {
    let id: Int
    let fullName: String?
    let email: String?
    let phone: String?
    let cp: CpInfo?
}

struct CpInfo: Codable {
    let city: String?
    let reraNumber: String?
    let tier: String?
    let totalDeals: Int?
    let dealsThisMonth: Int?
    let totalEarnings: Double?
    let pendingCommission: Double?
    let phoneVerified: Bool?
    let aadhaarVerified: Bool?
    let panVerified: Bool?
    let reraVerified: Bool?
    let aadhaarUrl: String?
    let panUrl: String?
    let reraUrl: String?
}

/// Response from `POST /cp/:cpUserId/documents` (multipart upload).
struct CpDocumentUploadResponse: Codable {
    let url: String?
    let docType: String?
}

/// A CRM contact — `cp/:id/contacts`.
struct CpContact: Codable, Identifiable {
    let id: Int
    let name: String?
    let phone: String?
    let bhkPreference: String?
}

/// A scheduled follow-up — `cp/:id/follow-ups`.
struct CpFollowUp: Codable, Identifiable {
    let id: String
    let customerName: String?
    let projectName: String?
    let reason: String?
    let dueDate: String?
    let dueTime: String?
}

/// A CP meeting / site visit — `cp/:id/meetings`.
struct CpMeeting: Codable, Identifiable {
    let id: Int
    let customerName: String?
    let customerPhone: String?
    let status: String?
    let preferredDate: String?
    let preferredTime: String?
    let confirmedDate: String?
    let confirmedTime: String?
    var whenText: String {
        [confirmedDate ?? preferredDate, confirmedTime ?? preferredTime]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// Today's meetings, follow-ups, and callbacks — `cp/:id/due-today`.
struct CpDueToday: Codable {
    let meetings: [DueMeeting]
    let followUps: [CpFollowUp]
    let callLogs: [DueCallLog]

    var count: Int { meetings.count + followUps.count + callLogs.count }

    struct DueMeeting: Codable, Identifiable {
        let id: String
        let customerName: String?
        let projectName: String?
        let meetingType: String?
        let time: String?
    }

    struct DueCallLog: Codable, Identifiable {
        let id: String
        let customerName: String?
        let projectName: String?
        let outcome: String?
    }
}

/// Full deal detail with the chat thread — `cp/:id/deals/:dealId`.
struct CpDealDetail: Codable, Identifiable {
    let id: Int
    let status: String?
    let customerName: String?
    let customerPhone: String?
    let projectName: String?
    let commissionAmount: Double?
    let commissionStatus: String?
    let messages: [DealMessage]?
}
