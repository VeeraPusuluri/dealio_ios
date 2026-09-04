import Foundation

/// A single chat message on a deal — `builder/:id/deals/:dealId` → messages[].
struct DealMessage: Codable, Identifiable {
    let id: Int
    let senderRole: String?
    let message: String
    let createdAt: String?
}

/// Full deal detail — `builder/:id/deals/:dealId`.
///
/// Messaging is deliberately absent: a conversation is between the builder and a
/// person, not about this deal, so it lives entirely in `ConversationsView` and
/// this page links there. See `ThreadService`.
struct DealDetail: Codable, Identifiable {
    let id: Int
    var status: String = ""
    var dealValue: Double?
    var isNRI: Bool = false
    var commissionStatus: String?
    var cpAgreed: Bool = false
    var customerConfirmed: Bool = false
    var createdAt: String = ""
    var updatedAt: String = ""
    var customerName: String = ""
    var customerPhone: String = ""
    var projectName: String = ""
    var cpName: String?
    var cpPhone: String?
    var cpTier: String?
    var commissionPercent: Double?
    var commissionAmount: Double?
    var dealDocuments: [DealDocument] = []
    var events: [DealEvent] = []
    var paymentSchedule: [Installment]?
    /// Only the legacy deal-scoped endpoints still send these.
    var messages: [DealMessage]?

    private enum CodingKeys: String, CodingKey {
        case id, status, dealValue, isNRI, commissionStatus, cpAgreed, customerConfirmed
        case createdAt, updatedAt, customerName, customerPhone, projectName
        case cpName, cpPhone, cpTier, commissionPercent, commissionAmount
        case dealDocuments, events, paymentSchedule, messages
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        dealValue = try c.decodeIfPresent(Double.self, forKey: .dealValue)
        isNRI = try c.decodeIfPresent(Bool.self, forKey: .isNRI) ?? false
        commissionStatus = try c.decodeIfPresent(String.self, forKey: .commissionStatus)
        cpAgreed = try c.decodeIfPresent(Bool.self, forKey: .cpAgreed) ?? false
        customerConfirmed = try c.decodeIfPresent(Bool.self, forKey: .customerConfirmed) ?? false
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
        customerName = try c.decodeIfPresent(String.self, forKey: .customerName) ?? ""
        customerPhone = try c.decodeIfPresent(String.self, forKey: .customerPhone) ?? ""
        projectName = try c.decodeIfPresent(String.self, forKey: .projectName) ?? ""
        cpName = try c.decodeIfPresent(String.self, forKey: .cpName)
        cpPhone = try c.decodeIfPresent(String.self, forKey: .cpPhone)
        cpTier = try c.decodeIfPresent(String.self, forKey: .cpTier)
        commissionPercent = try c.decodeIfPresent(Double.self, forKey: .commissionPercent)
        commissionAmount = try c.decodeIfPresent(Double.self, forKey: .commissionAmount)
        dealDocuments = try c.decodeIfPresent([DealDocument].self, forKey: .dealDocuments) ?? []
        events = try c.decodeIfPresent([DealEvent].self, forKey: .events) ?? []
        paymentSchedule = try c.decodeIfPresent([Installment].self, forKey: .paymentSchedule)
        messages = try c.decodeIfPresent([DealMessage].self, forKey: .messages)
    }
}

/// A document attached to a deal, and who it has been shared with.
struct DealDocument: Codable, Identifiable {
    let id: Int
    var name: String = ""
    var docType: String = ""
    var fileUrl: String?
    var uploadedByRole: String = "builder"
    var sharedWithCp: Bool = false
    var sharedWithCustomer: Bool = false
    var createdAt: String = ""

    var fileURL: URL? { AppConfig.resolveAssetURL(fileUrl) }

    private enum CodingKeys: String, CodingKey {
        case id, name, docType, fileUrl, uploadedByRole, sharedWithCp, sharedWithCustomer, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        docType = try c.decodeIfPresent(String.self, forKey: .docType) ?? ""
        fileUrl = try c.decodeIfPresent(String.self, forKey: .fileUrl)
        uploadedByRole = try c.decodeIfPresent(String.self, forKey: .uploadedByRole) ?? "builder"
        sharedWithCp = try c.decodeIfPresent(Bool.self, forKey: .sharedWithCp) ?? false
        sharedWithCustomer = try c.decodeIfPresent(Bool.self, forKey: .sharedWithCustomer) ?? false
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }
}

/// A demand-letter / payment-schedule line.
struct Installment: Codable, Identifiable {
    let installment: String?
    let amount: Double?
    let dueDate: String?
    let status: String?
    var id: String { (installment ?? "") + (dueDate ?? "") }
}

/// A broadcast to CPs/customers — `builder/:id/broadcasts`.
struct Broadcast: Codable, Identifiable {
    let id: Int
    let projectName: String?
    let message: String
    let audience: String?
    let delivered: Int?
    let createdAt: String?
}

struct BroadcastRequest: Encodable {
    let message: String
    let audience: String
    let projectId: Int?
    let projectName: String?
}

struct SendMessageRequest: Encodable {
    let message: String
}

/// A persisted notification — `{builder,cp,customer}/notifications`.
///
/// `link` is the web app's path for the thing that happened
/// ("/builder/deals/12", "/cp/leads"). The FCM push repeats it in its data
/// payload, so the tray entry and the in-app bell describe the same destination
/// — see `DeepLink`.
struct BuilderNotification: Codable, Identifiable {
    let id: Int
    let title: String?
    let message: String?
    let type: String?
    let link: String?
    var read: Bool?
    let createdAt: String?
}

/// Create / update payload — `POST builder/:id/projects`, `PATCH …/:projectId`.
///
/// Every field is optional and nil ones are dropped by the encoder, matching the
/// web wizard's `undefined`: sending nil means "leave this alone" rather than
/// "clear it". Mirrors Android's `ProjectPayload`.
struct ProjectPayload: Encodable {
    let name: String
    var city: String?
    var locality: String?
    var address: String?
    /// The one-line location the list views render; the wizard fills it from the
    /// most specific of address / locality / city.
    var location: String?
    var pincode: String?
    var landmark: String?
    var description: String?
    var status: String?
    var projectType: String?
    var configurations: [String]?
    /// The same list under the name the older endpoint reads.
    var bhkTypes: [String]?
    var amenities: [String]?
    var nearbyHighlights: [String]?
    var totalUnits: Int?
    var towers: Int?
    var floorsPerTower: Int?
    var reraNumber: String?
    var reraId: String?
    var reraExpiry: String?
    var reraState: String?
    var priceMin: Double?
    var priceMax: Double?
    var pricePerSqftMin: Double?
    var pricePerSqftMax: Double?
    var maintenanceCharges: Double?
    var floorRiseCharges: Double?
    var commissionStructure: String?
    var commissionValue: Double?
    var commissionPercent: Double?
    var cpIncentive: String?
    var possessionDate: String?
    var featured: Bool?
    var closingSoon: Bool?
    var videoUrl: String?
    var virtualTourUrl: String?
    var googleMapsLink: String?
    var landArea: String?
    var buildingPermitNumber: String?
    var clubhouseAreaSqft: Int?
    var specifications: Specifications?
    var paymentPlans: [PaymentPlan]?
    var locationAdvantages: [LocationAdvantage]?
    var builderName: String?
    var builderAbout: String?
    var builderYearEstablished: Int?
    var builderDeliveredProjects: Int?
    var builderWebsite: String?
}
