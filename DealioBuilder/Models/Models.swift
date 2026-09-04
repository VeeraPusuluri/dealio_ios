import Foundation

// MARK: - Auth

struct AuthUser: Codable, Identifiable {
    let id: Int
    let fullName: String?
    let phone: String?
    let role: String?
    let email: String?
    var avatarUrl: String?

    var avatarURL: URL? { AppConfig.resolveAssetURL(avatarUrl) }
}

struct AuthData: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    let user: AuthUser
}

struct EnsureBuilderData: Codable {
    let builderId: Int
}

// MARK: - Domain

// MARK: - Project detail supporting types

struct Specifications: Codable, Hashable {
    var structure: String?
    var flooring: String?
    var doors: String?
    var windows: String?
    var electrical: String?
    var plumbing: String?
    var kitchen: String?
    var bathrooms: String?
    var painting: String?
}

struct PaymentPlan: Codable, Hashable {
    var name: String?
    var description: String?
}

struct LocationAdvantage: Codable, Hashable {
    var category: String?
    var name: String?
    var distanceKm: String?
    var driveMinutes: String?
}

/// Mirrors the backend `toProjectDto` shape (raw project fields with
/// `priceFrom`/`priceTo` renamed to `priceMin`/`priceMax`). Unknown keys are ignored.
struct Project: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let city: String?
    let locality: String?
    let status: String?
    let projectType: String?
    let totalUnits: Int?
    let availableUnits: Int?
    let soldUnits: Int?
    let bookedUnits: Int?
    let priceMin: Double?
    let priceMax: Double?
    let imageUrl: String?
    let possessionDate: String?
    let reraNumber: String?
    let published: Bool?
    var featured: Bool? = nil
    var closingSoon: Bool? = nil
    var videoUrl: String? = nil
    var builderId: Int? = nil
    var configurations: [String]? = nil
    var amenities: [String]? = nil
    var nearbyHighlights: [String]? = nil
    var builderName: String? = nil
    var clubhouseAreaSqft: Int? = nil
    var floorsPerTower: Int? = nil
    // Extended detail fields
    var towers: Int? = nil
    var description: String? = nil
    var landArea: String? = nil
    var pricePerSqftMin: Double? = nil
    var pricePerSqftMax: Double? = nil
    /// The wizard's own spelling of the two above; the backend has shipped both.
    var pricePerSqftFrom: Double? = nil
    var pricePerSqftTo: Double? = nil
    var reraExpiry: String? = nil
    var reraState: String? = nil
    var address: String? = nil
    var pincode: String? = nil
    var landmark: String? = nil
    var googleMapsLink: String? = nil
    var buildingPermitNumber: String? = nil
    var maintenanceCharges: Double? = nil
    var floorRiseCharges: Double? = nil
    var commissionStructure: String? = nil
    var commissionValue: Double? = nil
    var cpIncentive: String? = nil
    var coverUrl: String? = nil
    var virtualTourUrl: String? = nil
    var builderAbout: String? = nil
    var builderWebsite: String? = nil
    var builderYearEstablished: Int? = nil
    var builderDeliveredProjects: Int? = nil
    /// The project's actual inventory. Absent on projects created before the
    /// wizard collected it — `Units.of(_:)` synthesizes a grid for those.
    var unitMatrix: [UnitRow]? = nil
    var specifications: Specifications? = nil
    var paymentPlans: [PaymentPlan]? = nil
    var locationAdvantages: [LocationAdvantage]? = nil

    /// Absolute URL for the cover image, resolving relative `/uploads/...` paths and
    /// upgrading remote `http://` URLs to `https://`.
    var imageURL: URL? { AppConfig.resolveAssetURL(imageUrl) }
}

/// Mirrors `getBuilderLeads`. Note `id` is a String on this endpoint.
struct Lead: Codable, Identifiable {
    let id: String
    let customerName: String?
    let phone: String?
    var email: String? = nil
    let projectName: String?
    var cpName: String? = nil
    let stage: String?
    let source: String?
    let budget: Double?
    let dealValue: Double?
    var notes: String? = nil
    let createdAt: String?
    /// Days since the row last moved — the staleness the move queue sorts by.
    let daysInStage: Int?
    let commissionStatus: String?

    /// The numeric deal id behind the row; `PATCH …/leads/:dealId/stage` needs it.
    var dealId: Int? { Int(id) }
}

/// Mirrors `getBuilderDeals`.
struct Deal: Codable, Identifiable {
    let id: Int
    let status: String?
    let dealValue: Double?
    let customerName: String?
    let customerPhone: String?
    let projectName: String?
    let cpName: String?
    let createdAt: String?
    var paymentSchedule: [Installment]? = nil
}
