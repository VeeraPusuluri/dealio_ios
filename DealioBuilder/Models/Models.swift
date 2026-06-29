import Foundation

// MARK: - Auth

struct AuthUser: Codable, Identifiable {
    let id: Int
    let fullName: String?
    let phone: String?
    let role: String?
    let email: String?
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
    var reraExpiry: String? = nil
    var builderYearEstablished: Int? = nil
    var builderDeliveredProjects: Int? = nil
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
    let projectName: String?
    let stage: String?
    let source: String?
    let budget: Double?
    let dealValue: Double?
    let createdAt: String?
    let daysInStage: Int?
    let commissionStatus: String?
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
