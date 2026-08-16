import Foundation

// Request bodies for everything the channel partner writes. Kept together so
// the CRM screens don't each declare a private `struct Body: Encodable` that
// nothing else can reuse.

/// `POST cp/:id/contacts` and `PATCH cp/:id/contacts/:contactId`.
struct CpContactPayload: Encodable {
    var name: String
    var phone: String
    /// Dial code, e.g. `+91`. Kept apart from `phone` — a contact imported from
    /// abroad is not an Indian number with odd digits in front.
    var countryCode: String = "+91"
    var email: String?
    var notes: String?
    var bhkPreference: String?
    var designation: String?
    var salary: Double?
    /// What they can put into property in a year.
    var investment: Double?
    var address: String?
}

/// `POST cp/:id/leads`.
struct CreateCpLeadRequest: Encodable {
    let projectId: Int
    let customerName: String
    let customerPhone: String
    var customerEmail: String?
    var stage: String = "NEW_LEAD"
}

/// `POST cp/:id/follow-ups`.
struct CreateFollowUpRequest: Encodable {
    let dealId: Int
    let dueDate: String
    var dueTime: String?
    let reason: String
}

/// `PATCH cp/:id/meetings/:meetingId/notes`.
struct MeetingNoteRequest: Encodable {
    let notes: String
    var cpRating: Int?
}

/// `PATCH cp/:id/profile`.
struct CpProfileUpdateRequest: Encodable {
    var fullName: String?
    var email: String?
    var city: String?
    var bio: String?
    var reraNumber: String?
}

/// `POST portal/customer/meetings` — a site visit with the builder.
///
/// A CP books on the buyer's behalf by passing their own `cpUserId` alongside
/// the customer's name and number, which is what keeps the resulting deal
/// attributed to them.
struct BookMeetingRequest: Encodable {
    let builderId: Int
    var projectId: Int?
    let customerName: String
    let customerPhone: String
    let preferredDate: String
    let preferredTime: String
    var meetingType: String?
    var notes: String?
    var cpUserId: Int?
}
