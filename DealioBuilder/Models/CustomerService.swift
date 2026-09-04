import Foundation

/// The buyer portal's write actions, in one place.
///
/// The endpoints are split across `/portal/customer/...` (the customer
/// controller) and `/builder/customer/...` (the builder controller, addressed to
/// the customer). Which is which is not something a screen should have to know.
/// Mirrors Android's `data/CustomerRepository.kt`.
enum CustomerService {
    private struct PhoneRequest: Encodable { let phone: String }
    private struct RateRequest: Encodable { let rating: Int }
    private struct PreferredCityRequest: Encodable { let city: String? }
    private struct ProfileUpdateRequest: Encodable { let email: String? }

    // MARK: Deals

    static func myDeals(phone: String) async throws -> [CustomerDeal] {
        try await APIClient.shared.get(APIClient.query("/portal/customer/deals", ["phone": phone]))
    }

    static func confirmDeal(_ dealId: Int, phone: String) async throws {
        try await APIClient.shared.patchVoid("/builder/customer/deals/\(dealId)/confirm",
                                             body: PhoneRequest(phone: phone))
    }

    static func acceptNegotiation(_ dealId: Int, phone: String) async throws {
        try await APIClient.shared.patchVoid("/portal/customer/deals/\(dealId)/accept-negotiation",
                                             body: PhoneRequest(phone: phone))
    }

    /// Submits the buyer's signed agreement.
    ///
    /// The route lives under `builder/customer/...` rather than `portal/...` —
    /// it is the builder controller's, addressed to the customer — and the phone
    /// travels as a form field beside the file rather than in a JSON body,
    /// because the request is multipart.
    static func uploadSignedAgreement(
        dealId: Int, phone: String, data: Data, fileName: String, mimeType: String
    ) async throws -> DealDocument {
        try await APIClient.shared.upload(
            "/builder/customer/deals/\(dealId)/signed-agreement",
            fileData: data, fileName: fileName, mimeType: mimeType,
            fields: ["phone": phone]
        )
    }

    // MARK: Projects & discovery

    static func project(_ id: Int) async throws -> Project {
        try await APIClient.shared.get("/customer/projects/\(id)")
    }

    static func cities() async throws -> [String] {
        try await APIClient.shared.get("/customer/cities")
    }

    static func setPreferredCity(_ city: String?) async throws {
        try await APIClient.shared.patchVoid("/customer/preferred-city",
                                             body: PreferredCityRequest(city: city))
    }

    static func updateProfile(email: String?) async throws {
        try await APIClient.shared.patchVoid("/customer/profile",
                                             body: ProfileUpdateRequest(email: email))
    }

    // MARK: Shortlists & pricing

    struct ShortlistRequest: Encodable {
        let customerPhone: String
        let builderId: Int
        let projectId: Int
        let cpId: Int?
        let unitId: String
        let unitDetails: [String: String]
    }

    struct PricingRequest: Encodable {
        let builderId: Int
        let projectId: Int
        let customerPhone: String
        let unitId: String
        let unitDetails: [String: String]
        let note: String?
    }

    /// `unitDetails` mirrors the shape the website sends so a shortlist made in
    /// the app renders identically in the builder's queue — same keys, same
    /// strings, no second format for the same record.
    static func unitDetails(_ unit: UnitRow) -> [String: String] {
        var details: [String: String] = ["unitNumber": unit.id]
        if let tower = unit.tower, !tower.isEmpty { details["tower"] = tower }
        if let floor = unit.floor { details["floor"] = "\(floor)" }
        if let bhk = unit.bhk, !bhk.isEmpty { details["bhkType"] = bhk }
        if let area = unit.areaSqft, area > 0 { details["carpetArea"] = "\(area) sqft" }
        if let facing = unit.facing, !facing.isEmpty { details["facing"] = facing }
        if let status = unit.status, !status.isEmpty { details["status"] = status }
        return details
    }

    static func shortlistUnit(_ request: ShortlistRequest) async throws {
        try await APIClient.shared.postVoid("/portal/customer/shortlist", body: request)
    }

    static func requestPricing(_ request: PricingRequest) async throws {
        try await APIClient.shared.postVoid("/portal/customer/pricing-requests", body: request)
    }

    // MARK: Site visits

    static func meetings(phone: String) async throws -> [CustomerMeeting] {
        try await APIClient.shared.get(APIClient.query("/portal/customer/meetings", ["phone": phone]))
    }

    struct BookMeetingRequest: Encodable {
        let builderId: Int
        let projectId: Int?
        let customerName: String
        let customerPhone: String
        let preferredDate: String
        let preferredTime: String
        let meetingType: String?
        let cpId: Int?
    }

    static func bookMeeting(_ request: BookMeetingRequest) async throws {
        try await APIClient.shared.postVoid("/portal/customer/meetings", body: request)
    }

    /// Slots already taken for a builder on a date, so the picker can grey them.
    static func bookedSlots(builderId: Int, date: String) async throws -> [String] {
        try await APIClient.shared.get(APIClient.query("/portal/customer/booked-slots",
                                                       ["builderId": "\(builderId)", "date": date]))
    }

    static func rateMeeting(_ meetingId: Int, rating: Int) async throws {
        try await APIClient.shared.patchVoid("/portal/customer/meetings/\(meetingId)/rating",
                                             body: RateRequest(rating: rating))
    }

    // MARK: Saved projects (bookmarks) — the caller is read from the token

    struct SavedProjectResult: Codable { var projectId: Int = 0; var saved: Bool = false }

    static func savedProjects() async throws -> [Project] {
        try await APIClient.shared.get("/customer/saved-projects")
    }

    @discardableResult
    static func saveProject(_ projectId: Int) async throws -> SavedProjectResult {
        try await APIClient.shared.post("/customer/saved-projects/\(projectId)")
    }

    @discardableResult
    static func unsaveProject(_ projectId: Int) async throws -> SavedProjectResult {
        try await APIClient.shared.delete("/customer/saved-projects/\(projectId)")
    }

    // MARK: Home loan

    struct LoanApplicationRequest: Encodable {
        let builderId: Int?
        let projectId: Int?
        let customerName: String?
        let customerPhone: String
        let customerEmail: String?
        let loanAmount: Double
        let propertyValue: Double
        let employmentType: String?
        let tenureMonths: Int
    }

    static func submitLoanApplication(_ request: LoanApplicationRequest) async throws {
        try await APIClient.shared.postVoid("/portal/customer/applications", body: request)
    }

    // MARK: Channel partners available to assist

    static func availableCPs(city: String?) async throws -> [AvailableCP] {
        try await APIClient.shared.get(APIClient.query("/customer/cps", ["city": city]))
    }
}
