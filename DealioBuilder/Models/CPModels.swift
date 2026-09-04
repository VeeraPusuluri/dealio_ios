import Foundation

// MARK: - Channel-partner domain models
//
// Mirror the backend `/cp/:cpUserId/...` DTOs (Android's `data/api/CpModels.kt`).
// Every non-essential field is optional or defaulted so a partial payload still
// decodes — the app ships both ahead of and behind the backend.

/// A lead referred by this CP — `cp/:id/leads`.
struct CpLead: Codable, Identifiable {
    let id: Int
    var projectId: Int = 0
    var projectName: String = "Unknown"
    var builderId: Int?
    var customerName: String = "Unknown"
    var customerPhone: String = ""
    var customerEmail: String?
    var dealValue: Double?
    var status: String = ""
    var cpAgreed = false
    var customerConfirmed = false
    var commissionStatus: String = "Pending"
    var commissionPercent: Double?
    var estimatedCommission: Double?
    var createdAt: String = ""
    var updatedAt: String = ""

    private enum CodingKeys: String, CodingKey {
        case id, projectId, projectName, builderId, customerName, customerPhone, customerEmail
        case dealValue, status, cpAgreed, customerConfirmed, commissionStatus
        case commissionPercent, estimatedCommission, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        projectId = try c.decodeIfPresent(Int.self, forKey: .projectId) ?? 0
        projectName = try c.decodeIfPresent(String.self, forKey: .projectName) ?? "Unknown"
        builderId = try c.decodeIfPresent(Int.self, forKey: .builderId)
        customerName = try c.decodeIfPresent(String.self, forKey: .customerName) ?? "Unknown"
        customerPhone = try c.decodeIfPresent(String.self, forKey: .customerPhone) ?? ""
        customerEmail = try c.decodeIfPresent(String.self, forKey: .customerEmail)
        dealValue = try c.decodeIfPresent(Double.self, forKey: .dealValue)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        cpAgreed = try c.decodeIfPresent(Bool.self, forKey: .cpAgreed) ?? false
        customerConfirmed = try c.decodeIfPresent(Bool.self, forKey: .customerConfirmed) ?? false
        commissionStatus = try c.decodeIfPresent(String.self, forKey: .commissionStatus) ?? "Pending"
        commissionPercent = try c.decodeIfPresent(Double.self, forKey: .commissionPercent)
        estimatedCommission = try c.decodeIfPresent(Double.self, forKey: .estimatedCommission)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }
}

/// Full deal detail as the partner sees it — `cp/:id/deals/:dealId`.
struct CpDealDetail: Codable, Identifiable {
    let id: Int
    var projectId: Int?
    var builderId: Int?
    var status: String = ""
    var dealValue: Double?
    var commissionStatus: String?
    var cpAgreed = false
    var customerConfirmed = false
    var createdAt: String = ""
    var updatedAt: String = ""
    var customerName: String = ""
    var customerPhone: String = ""
    var projectName: String = ""
    var cpTier: String?
    var commissionPercent: Double?
    var commissionAmount: Double?
    var dealDocuments: [DealDocument] = []
    var events: [DealEvent] = []
    /// Only the legacy deal-scoped chat endpoint still sends these.
    var messages: [DealMessage]?

    private enum CodingKeys: String, CodingKey {
        case id, projectId, builderId, status, dealValue, commissionStatus, cpAgreed
        case customerConfirmed, createdAt, updatedAt, customerName, customerPhone
        case projectName, cpTier, commissionPercent, commissionAmount
        case dealDocuments, events, messages
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        projectId = try c.decodeIfPresent(Int.self, forKey: .projectId)
        builderId = try c.decodeIfPresent(Int.self, forKey: .builderId)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        dealValue = try c.decodeIfPresent(Double.self, forKey: .dealValue)
        commissionStatus = try c.decodeIfPresent(String.self, forKey: .commissionStatus)
        cpAgreed = try c.decodeIfPresent(Bool.self, forKey: .cpAgreed) ?? false
        customerConfirmed = try c.decodeIfPresent(Bool.self, forKey: .customerConfirmed) ?? false
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
        customerName = try c.decodeIfPresent(String.self, forKey: .customerName) ?? ""
        customerPhone = try c.decodeIfPresent(String.self, forKey: .customerPhone) ?? ""
        projectName = try c.decodeIfPresent(String.self, forKey: .projectName) ?? ""
        cpTier = try c.decodeIfPresent(String.self, forKey: .cpTier)
        commissionPercent = try c.decodeIfPresent(Double.self, forKey: .commissionPercent)
        commissionAmount = try c.decodeIfPresent(Double.self, forKey: .commissionAmount)
        dealDocuments = try c.decodeIfPresent([DealDocument].self, forKey: .dealDocuments) ?? []
        events = try c.decodeIfPresent([DealEvent].self, forKey: .events) ?? []
        messages = try c.decodeIfPresent([DealMessage].self, forKey: .messages)
    }
}

/// A commission line — `cp/:id/commissions`.
struct CpCommission: Codable, Identifiable {
    let id: Int
    var status: String = ""
    var dealValue: Double?
    var commissionStatus: String?
    var commissionPercent: Double = 0
    var commissionAmount: Double = 0
    var commissionReleasedAt: String?
    var customerName: String = "Unknown"
    var projectName: String = "Unknown"
    var projectCity: String = ""
    var cpTier: String?

    private enum CodingKeys: String, CodingKey {
        case id, status, dealValue, commissionStatus, commissionPercent, commissionAmount
        case commissionReleasedAt, customerName, projectName, projectCity, cpTier
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        dealValue = try c.decodeIfPresent(Double.self, forKey: .dealValue)
        commissionStatus = try c.decodeIfPresent(String.self, forKey: .commissionStatus)
        commissionPercent = try c.decodeIfPresent(Double.self, forKey: .commissionPercent) ?? 0
        commissionAmount = try c.decodeIfPresent(Double.self, forKey: .commissionAmount) ?? 0
        commissionReleasedAt = try c.decodeIfPresent(String.self, forKey: .commissionReleasedAt)
        customerName = try c.decodeIfPresent(String.self, forKey: .customerName) ?? "Unknown"
        projectName = try c.decodeIfPresent(String.self, forKey: .projectName) ?? "Unknown"
        projectCity = try c.decodeIfPresent(String.self, forKey: .projectCity) ?? ""
        cpTier = try c.decodeIfPresent(String.self, forKey: .cpTier)
    }
}

// MARK: - Profile & verification

struct CpProfile: Codable {
    var id: Int = 0
    var fullName: String?
    var email: String?
    var phone: String?
    var cp: CpInfo?
    /// Builders that have formally authorised this CP to represent them.
    var authorizedBuilders: [CpAuthorizedBuilder] = []

    private enum CodingKeys: String, CodingKey {
        case id, fullName, email, phone, cp, authorizedBuilders
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        fullName = try c.decodeIfPresent(String.self, forKey: .fullName)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        phone = try c.decodeIfPresent(String.self, forKey: .phone)
        cp = try c.decodeIfPresent(CpInfo.self, forKey: .cp)
        authorizedBuilders = try c.decodeIfPresent([CpAuthorizedBuilder].self, forKey: .authorizedBuilders) ?? []
    }
}

struct CpAuthorizedBuilder: Codable, Identifiable {
    var builderId: Int = 0
    var companyName: String = ""
    var authorizedAt: String?
    var id: Int { builderId }
}

struct CpInfo: Codable {
    var city: String?
    var bio: String?
    var reraNumber: String?
    var photoUrl: String?
    var tier: String = "Silver"
    var totalDeals: Int = 0
    var dealsThisMonth: Int = 0
    var totalEarnings: Double = 0
    var pendingCommission: Double = 0
    var influencerScore: Int = 0
    var joinedDate: String?
    var phoneVerified = false
    var aadhaarVerified = false
    var panVerified = false
    var reraVerified = false
    var aadhaarUrl: String?
    var panUrl: String?
    var reraUrl: String?

    private enum CodingKeys: String, CodingKey {
        case city, bio, reraNumber, photoUrl, tier, totalDeals, dealsThisMonth
        case totalEarnings, pendingCommission, influencerScore, joinedDate
        case phoneVerified, aadhaarVerified, panVerified, reraVerified
        case aadhaarUrl, panUrl, reraUrl
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        city = try c.decodeIfPresent(String.self, forKey: .city)
        bio = try c.decodeIfPresent(String.self, forKey: .bio)
        reraNumber = try c.decodeIfPresent(String.self, forKey: .reraNumber)
        photoUrl = try c.decodeIfPresent(String.self, forKey: .photoUrl)
        tier = try c.decodeIfPresent(String.self, forKey: .tier) ?? "Silver"
        totalDeals = try c.decodeIfPresent(Int.self, forKey: .totalDeals) ?? 0
        dealsThisMonth = try c.decodeIfPresent(Int.self, forKey: .dealsThisMonth) ?? 0
        totalEarnings = try c.decodeIfPresent(Double.self, forKey: .totalEarnings) ?? 0
        pendingCommission = try c.decodeIfPresent(Double.self, forKey: .pendingCommission) ?? 0
        influencerScore = try c.decodeIfPresent(Int.self, forKey: .influencerScore) ?? 0
        joinedDate = try c.decodeIfPresent(String.self, forKey: .joinedDate)
        phoneVerified = try c.decodeIfPresent(Bool.self, forKey: .phoneVerified) ?? false
        aadhaarVerified = try c.decodeIfPresent(Bool.self, forKey: .aadhaarVerified) ?? false
        panVerified = try c.decodeIfPresent(Bool.self, forKey: .panVerified) ?? false
        reraVerified = try c.decodeIfPresent(Bool.self, forKey: .reraVerified) ?? false
        aadhaarUrl = try c.decodeIfPresent(String.self, forKey: .aadhaarUrl)
        panUrl = try c.decodeIfPresent(String.self, forKey: .panUrl)
        reraUrl = try c.decodeIfPresent(String.self, forKey: .reraUrl)
    }
}

/// Response from `POST /cp/:cpUserId/documents` (multipart upload).
struct CpDocumentUploadResponse: Codable {
    let url: String?
    let docType: String?
}

// MARK: - CRM

/// A CRM contact — `cp/:id/contacts`.
struct CpContact: Codable, Identifiable, Hashable {
    let id: Int
    var name: String = ""
    var countryCode: String?
    var phone: String = ""
    var email: String?
    var notes: String?
    var tags: String?
    var bhkPreference: String?
    var designation: String?
    var salary: Double?
    /// What they can put into property in a year. Seeded from salary on import.
    var investment: Double?
    var address: String?
    var createdAt: String = ""

    /// The number as it should be dialled — country code included when stored.
    var dialable: String { (countryCode ?? "") + phone }

    private enum CodingKeys: String, CodingKey {
        case id, name, countryCode, phone, email, notes, tags, bhkPreference
        case designation, salary, investment, address, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        countryCode = try c.decodeIfPresent(String.self, forKey: .countryCode)
        phone = try c.decodeIfPresent(String.self, forKey: .phone) ?? ""
        email = try c.decodeIfPresent(String.self, forKey: .email)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        tags = try c.decodeIfPresent(String.self, forKey: .tags)
        bhkPreference = try c.decodeIfPresent(String.self, forKey: .bhkPreference)
        designation = try c.decodeIfPresent(String.self, forKey: .designation)
        salary = try c.decodeIfPresent(Double.self, forKey: .salary)
        investment = try c.decodeIfPresent(Double.self, forKey: .investment)
        address = try c.decodeIfPresent(String.self, forKey: .address)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }
}

struct CpContactPayload: Encodable {
    var name: String
    var phone: String
    var countryCode: String = "+91"
    var email: String?
    var notes: String?
    var tags: String?
    var bhkPreference: String?
    var designation: String?
    var salary: Double?
    var investment: Double?
    var address: String?
}

/// A scheduled follow-up — `cp/:id/follow-ups`.
struct CpFollowUp: Codable, Identifiable {
    var id: String = ""
    var customerName: String = "Unknown"
    var projectName: String = "Unknown"
    var reason: String = ""
    var dueDate: String = ""
    var dueTime: String?
    var done = false

    private enum CodingKeys: String, CodingKey {
        case id, customerName, projectName, reason, dueDate, dueTime, done
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // The endpoint has shipped this as both a string and a number.
        if let string = try? c.decode(String.self, forKey: .id) { id = string }
        else if let number = try? c.decode(Int.self, forKey: .id) { id = "\(number)" }
        customerName = try c.decodeIfPresent(String.self, forKey: .customerName) ?? "Unknown"
        projectName = try c.decodeIfPresent(String.self, forKey: .projectName) ?? "Unknown"
        reason = try c.decodeIfPresent(String.self, forKey: .reason) ?? ""
        dueDate = try c.decodeIfPresent(String.self, forKey: .dueDate) ?? ""
        dueTime = try c.decodeIfPresent(String.self, forKey: .dueTime)
        done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
    }
}

/// A logged call — `cp/:id/call-logs`.
struct CpCallLog: Codable, Identifiable {
    var id: String = ""
    var customerName: String = "Unknown"
    var projectName: String = "Unknown"
    var outcome: String = ""
    var duration: String = ""
    var notes: String?
    var nextFollowUp: String?
    var nextFollowUpTime: String?
    var createdAt: String?

    private enum CodingKeys: String, CodingKey {
        case id, customerName, projectName, outcome, duration, notes
        case nextFollowUp, nextFollowUpTime, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let string = try? c.decode(String.self, forKey: .id) { id = string }
        else if let number = try? c.decode(Int.self, forKey: .id) { id = "\(number)" }
        customerName = try c.decodeIfPresent(String.self, forKey: .customerName) ?? "Unknown"
        projectName = try c.decodeIfPresent(String.self, forKey: .projectName) ?? "Unknown"
        outcome = try c.decodeIfPresent(String.self, forKey: .outcome) ?? ""
        duration = try c.decodeIfPresent(String.self, forKey: .duration) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        nextFollowUp = try c.decodeIfPresent(String.self, forKey: .nextFollowUp)
        nextFollowUpTime = try c.decodeIfPresent(String.self, forKey: .nextFollowUpTime)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

/// A CP meeting / site visit — `cp/:id/meetings`.
struct CpMeeting: Codable, Identifiable {
    let id: Int
    var customerName: String?
    var customerPhone: String?
    var projectName: String?
    var status: String?
    var preferredDate: String?
    var preferredTime: String?
    var confirmedDate: String?
    var confirmedTime: String?
    var notes: String?
    var cpRating: Int?

    var whenText: String {
        [confirmedDate ?? preferredDate, confirmedTime ?? preferredTime]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// Today's meetings, follow-ups, and callbacks — `cp/:id/due-today`.
struct CpDueToday: Decodable {
    var meetings: [DueMeeting] = []
    var followUps: [CpFollowUp] = []
    var callbacks: [DueMeeting] = []

    var count: Int { meetings.count + followUps.count + callbacks.count }

    struct DueMeeting: Decodable, Identifiable {
        var id: String = ""
        var customerName: String = ""
        var projectName: String = ""
        var time: String?
        var status: String = ""

        private enum CodingKeys: String, CodingKey { case id, customerName, projectName, time, status }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if let string = try? c.decode(String.self, forKey: .id) { id = string }
            else if let number = try? c.decode(Int.self, forKey: .id) { id = "\(number)" }
            customerName = try c.decodeIfPresent(String.self, forKey: .customerName) ?? ""
            projectName = try c.decodeIfPresent(String.self, forKey: .projectName) ?? ""
            time = try c.decodeIfPresent(String.self, forKey: .time)
            status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        }
    }

    private enum CodingKeys: String, CodingKey { case meetings, followUps, callbacks, callLogs }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        meetings = try c.decodeIfPresent([DueMeeting].self, forKey: .meetings) ?? []
        followUps = try c.decodeIfPresent([CpFollowUp].self, forKey: .followUps) ?? []
        // The endpoint has used both spellings for the callback list.
        callbacks = try c.decodeIfPresent([DueMeeting].self, forKey: .callbacks)
            ?? c.decodeIfPresent([DueMeeting].self, forKey: .callLogs) ?? []
    }
}

/// What `POST /cp/:id/projects/:pid/share-link` answers with.
struct ShareLinkResponse: Codable {
    var token: String = ""
    var url: String = ""
    var qr: String?
    var clickCount: Int = 0
}
