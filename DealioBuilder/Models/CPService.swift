import Foundation

/// Everything the channel-partner portal asks of the backend.
///
/// Every route is keyed by the CP's *user* id (not their CP-profile id), which
/// is what `AuthStore.user?.id` holds. Mirrors Android's `data/CpRepository.kt`.
enum CPService {
    // MARK: Projects

    /// Published projects a partner may refer. Not the builder's own list — this
    /// route is the platform-wide catalogue.
    static func projects() async throws -> [Project] {
        try await APIClient.shared.get("/builder/projects")
    }

    static func project(_ id: Int) async throws -> Project {
        try await APIClient.shared.get("/customer/projects/\(id)")
    }

    static func projectDocuments(builderId: Int, projectId: Int) async throws -> [ProjectDocument] {
        try await APIClient.shared.get("/builder/\(builderId)/projects/\(projectId)/documents")
    }

    /// A trackable link the partner shares with a buyer; clicks attribute back.
    static func shareLink(cpUserId: Int, projectId: Int) async throws -> ShareLinkResponse {
        try await APIClient.shared.post("/cp/\(cpUserId)/projects/\(projectId)/share-link")
    }

    // MARK: Leads & deals

    static func leads(cpUserId: Int) async throws -> [CpLead] {
        try await APIClient.shared.get("/cp/\(cpUserId)/leads")
    }

    struct CreateLeadRequest: Encodable {
        let projectId: Int
        let customerName: String
        let customerPhone: String
        var customerEmail: String?
        var stage: String = "NEW_LEAD"
    }

    static func createLead(cpUserId: Int, _ request: CreateLeadRequest) async throws {
        try await APIClient.shared.postVoid("/cp/\(cpUserId)/leads", body: request)
    }

    static func deal(cpUserId: Int, dealId: Int) async throws -> CpDealDetail {
        try await APIClient.shared.get("/cp/\(cpUserId)/deals/\(dealId)")
    }

    /// The partner's half of the Agreement stage.
    static func agreeToDeal(cpUserId: Int, dealId: Int) async throws {
        try await APIClient.shared.patchVoid("/cp/\(cpUserId)/deals/\(dealId)/agree")
    }

    static func commissions(cpUserId: Int) async throws -> [CpCommission] {
        try await APIClient.shared.get("/cp/\(cpUserId)/commissions")
    }

    // MARK: Contacts

    static func contacts(cpUserId: Int) async throws -> [CpContact] {
        try await APIClient.shared.get("/cp/\(cpUserId)/contacts")
    }

    @discardableResult
    static func createContact(cpUserId: Int, _ payload: CpContactPayload) async throws -> CpContact {
        try await APIClient.shared.post("/cp/\(cpUserId)/contacts", body: payload)
    }

    static func updateContact(cpUserId: Int, contactId: Int, _ payload: CpContactPayload) async throws {
        try await APIClient.shared.patchVoid("/cp/\(cpUserId)/contacts/\(contactId)", body: payload)
    }

    static func deleteContact(cpUserId: Int, contactId: Int) async throws {
        try await APIClient.shared.deleteVoid("/cp/\(cpUserId)/contacts/\(contactId)")
    }

    // MARK: Meetings

    static func meetings(cpUserId: Int) async throws -> [CpMeeting] {
        try await APIClient.shared.get("/cp/\(cpUserId)/meetings")
    }

    struct MeetingNoteRequest: Encodable { let notes: String; var cpRating: Int? }

    static func saveMeetingNotes(cpUserId: Int, meetingId: Int, _ request: MeetingNoteRequest) async throws {
        try await APIClient.shared.patchVoid("/cp/\(cpUserId)/meetings/\(meetingId)/notes", body: request)
    }

    /// Booking a visit on the buyer's behalf goes through the customer portal's
    /// own endpoint — there is one booking route, whoever fills the form.
    static func bookMeeting(_ request: CustomerService.BookMeetingRequest) async throws {
        try await APIClient.shared.postVoid("/portal/customer/meetings", body: request)
    }

    // MARK: The day's work

    static func dueToday(cpUserId: Int) async throws -> CpDueToday {
        try await APIClient.shared.get("/cp/\(cpUserId)/due-today")
    }

    static func followUps(cpUserId: Int) async throws -> [CpFollowUp] {
        try await APIClient.shared.get("/cp/\(cpUserId)/follow-ups")
    }

    struct CreateFollowUpRequest: Encodable {
        let dealId: Int
        let dueDate: String
        var dueTime: String?
        let reason: String
    }

    static func createFollowUp(cpUserId: Int, _ request: CreateFollowUpRequest) async throws {
        try await APIClient.shared.postVoid("/cp/\(cpUserId)/follow-ups", body: request)
    }

    static func markFollowUpDone(cpUserId: Int, id: String) async throws {
        try await APIClient.shared.patchVoid("/cp/\(cpUserId)/follow-ups/\(id)/done")
    }

    static func callLogs(cpUserId: Int) async throws -> [CpCallLog] {
        try await APIClient.shared.get("/cp/\(cpUserId)/call-logs")
    }

    struct CreateCallLogRequest: Encodable {
        let dealId: Int
        let outcome: String
        let duration: String
        var notes: String?
        var nextFollowUp: String?
        var nextFollowUpTime: String?
    }

    static func createCallLog(cpUserId: Int, _ request: CreateCallLogRequest) async throws {
        try await APIClient.shared.postVoid("/cp/\(cpUserId)/call-logs", body: request)
    }

    // MARK: Profile & verification

    static func profile(cpUserId: Int) async throws -> CpProfile {
        try await APIClient.shared.get("/cp/\(cpUserId)/profile")
    }

    struct ProfileUpdateRequest: Encodable {
        var fullName: String?
        var email: String?
        var city: String?
        var bio: String?
        var reraNumber: String?
    }

    static func updateProfile(cpUserId: Int, _ request: ProfileUpdateRequest) async throws {
        try await APIClient.shared.patchVoid("/cp/\(cpUserId)/profile", body: request)
    }

    private struct SendPhoneOtpRequest: Encodable { let phone: String }
    private struct VerifyPhoneRequest: Encodable { let phone: String; let otp: String }

    static func sendPhoneOTP(phone: String) async throws {
        try await APIClient.shared.postVoid("/cp/verify-phone/send-otp",
                                            body: SendPhoneOtpRequest(phone: phone))
    }

    static func verifyPhone(cpUserId: Int, phone: String, otp: String) async throws {
        try await APIClient.shared.postVoid("/cp/\(cpUserId)/verify-phone",
                                            body: VerifyPhoneRequest(phone: phone, otp: otp))
    }

    /// Uploads an identity document. `docType` is "aadhaar" | "pan" | "rera".
    @discardableResult
    static func uploadDocument(
        cpUserId: Int, docType: String, data: Data, fileName: String, mimeType: String
    ) async throws -> CpDocumentUploadResponse {
        try await APIClient.shared.upload("/cp/\(cpUserId)/documents",
                                          fileData: data, fileName: fileName, mimeType: mimeType,
                                          fields: ["docType": docType])
    }

    // MARK: Meetups

    static func meetups(cpUserId: Int) async throws -> [CpMeetup] {
        try await APIClient.shared.get("/cp/\(cpUserId)/meetups")
    }

    static func meetup(cpUserId: Int, meetupId: Int) async throws -> CpMeetup {
        try await APIClient.shared.get("/cp/\(cpUserId)/meetups/\(meetupId)")
    }

    struct CreateMeetupRequest: Encodable {
        let title: String
        let location: String
        let date: String
        let time: String
        var description: String?
        var category: String = "SITE_VISIT"
        var coverImage: String?
        var photos: [String] = []
        var topics: [String] = []
        var city: String?
        var mapsLink: String?
        var mode: String = "IN_PERSON"
        var onlineLink: String?
        var notes: String?
        var visibility: String = "PUBLIC"
        var capacity: Int?
        var invitees: [CpMeetupInviteePayload] = []
    }

    /// Every field is optional: an edit sends only what changed. `coverImage: ""`
    /// clears the cover; omitting it leaves whatever is stored alone.
    struct UpdateMeetupRequest: Encodable {
        var title: String?
        var description: String?
        var category: String?
        var coverImage: String?
        var photos: [String]?
        var topics: [String]?
        var location: String?
        var city: String?
        var mapsLink: String?
        var mode: String?
        var onlineLink: String?
        var date: String?
        var time: String?
        var notes: String?
        var visibility: String?
        var capacity: Int?
    }

    @discardableResult
    static func createMeetup(cpUserId: Int, _ request: CreateMeetupRequest) async throws -> CpMeetup {
        try await APIClient.shared.post("/cp/\(cpUserId)/meetups", body: request)
    }

    @discardableResult
    static func updateMeetup(cpUserId: Int, meetupId: Int, _ request: UpdateMeetupRequest) async throws -> CpMeetup {
        try await APIClient.shared.put("/cp/\(cpUserId)/meetups/\(meetupId)", body: request)
    }

    private struct CancelMeetupRequest: Encodable { let reason: String? }

    static func cancelMeetup(cpUserId: Int, meetupId: Int, reason: String?) async throws {
        try await APIClient.shared.postVoid("/cp/\(cpUserId)/meetups/\(meetupId)/cancel",
                                            body: CancelMeetupRequest(reason: reason))
    }

    static func deleteMeetup(cpUserId: Int, meetupId: Int) async throws {
        try await APIClient.shared.deleteVoid("/cp/\(cpUserId)/meetups/\(meetupId)")
    }

    static func invitable(cpUserId: Int) async throws -> InvitableResponse {
        try await APIClient.shared.get("/cp/\(cpUserId)/meetups/invitable")
    }

    @discardableResult
    static func uploadMeetupPhoto(
        cpUserId: Int, data: Data, fileName: String, mimeType: String
    ) async throws -> MeetupPhotoUpload {
        try await APIClient.shared.upload("/cp/\(cpUserId)/meetups/photo",
                                          fileData: data, fileName: fileName, mimeType: mimeType)
    }

    private struct AddInviteesRequest: Encodable { let invitees: [CpMeetupInviteePayload] }
    private struct SetRsvpRequest: Encodable { var rsvp: String?; var guests: Int? }

    static func addInvitees(cpUserId: Int, meetupId: Int, _ invitees: [CpMeetupInviteePayload]) async throws {
        try await APIClient.shared.postVoid("/cp/\(cpUserId)/meetups/\(meetupId)/invitees",
                                            body: AddInviteesRequest(invitees: invitees))
    }

    /// Sets an invitee's RSVP, their guest count, or both. The organiser uses
    /// this to record a reply that came by phone, and to check people in.
    static func setInviteeRSVP(
        cpUserId: Int, meetupId: Int, inviteeId: Int, rsvp: String?, guests: Int?
    ) async throws {
        try await APIClient.shared.patchVoid(
            "/cp/\(cpUserId)/meetups/\(meetupId)/invitees/\(inviteeId)",
            body: SetRsvpRequest(rsvp: rsvp, guests: guests)
        )
    }

    static func removeInvitee(cpUserId: Int, meetupId: Int, inviteeId: Int) async throws {
        try await APIClient.shared.deleteVoid("/cp/\(cpUserId)/meetups/\(meetupId)/invitees/\(inviteeId)")
    }
}

// MARK: - The buyer's side of meetups

extension CustomerService {
    /// Public meetups discoverable in a city.
    ///
    /// Passing no city lets the server fall back to this customer's saved
    /// preference, which is the case that matters — the list should be right
    /// without the app having to know what they picked.
    static func meetups(city: String? = nil, category: String? = nil) async throws -> CustomerMeetupFeed {
        try await APIClient.shared.get(
            APIClient.query("/customer/meetups", ["city": city, "category": category])
        )
    }

    static func meetup(_ id: Int) async throws -> CustomerMeetup {
        try await APIClient.shared.get("/customer/meetups/\(id)")
    }

    private struct RsvpRequest: Encodable { let rsvp: String; let guests: Int }

    /// Answers, and gets the updated row back so the list can swap the one card
    /// rather than refetching and losing its scroll position.
    @discardableResult
    static func rsvpToMeetup(_ id: Int, rsvp: Rsvp, guests: Int = 0) async throws -> CustomerMeetup {
        try await APIClient.shared.post("/customer/meetups/\(id)/rsvp",
                                        body: RsvpRequest(rsvp: rsvp.rawValue, guests: guests))
    }
}
