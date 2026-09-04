import Foundation

// MARK: - Meetups
//
// A gathering hosted by a channel partner: a site visit, an open house, an
// investor evening. The organiser owns the invite list; a public meetup is also
// discoverable by buyers in its city. Mirrors the meetup half of Android's
// `data/api/CpModels.kt` and `data/api/CustomerModels.kt`.

struct CpMeetup: Codable, Identifiable {
    let id: Int
    var title: String = ""
    var description: String?
    /// See `MeetupCategory`.
    var category: String = "SITE_VISIT"
    /// The photograph at the top of the event page. nil falls back to the
    /// category wash.
    var coverImage: String?
    /// Venue photographs, in upload order.
    var photos: [String] = []
    /// What it is about, in the organiser's words — "First-time buyers", "NRI".
    var topics: [String] = []
    var location: String = ""
    /// What a customer's preferred city is matched against.
    var city: String?
    var mapsLink: String?
    /// IN_PERSON | ONLINE | HYBRID
    var mode: String = "IN_PERSON"
    var onlineLink: String?
    var date: String = ""
    var time: String = ""
    var startAt: String?
    var notes: String?
    /// PRIVATE — invite list only. PUBLIC — also discoverable in `city`.
    var visibility: String = "PUBLIC"
    /// SCHEDULED | CANCELLED
    var status: String = "SCHEDULED"
    var cancelReason: String?
    var capacity: Int?
    var invitees: [CpMeetupInvitee] = []
    var counts: CpMeetupCounts = CpMeetupCounts()
    var createdAt: String = ""

    var isCancelled: Bool { status == "CANCELLED" }
    var isPublic: Bool { visibility == "PUBLIC" }
    /// Full only once a cap is set and the confirmed heads have reached it.
    var isFull: Bool { capacity.map { counts.goingHeads >= $0 } ?? false }

    var coverURL: URL? { AppConfig.resolveAssetURL(coverImage) }
    var whenText: String { [date, time].filter { !$0.isEmpty }.joined(separator: " · ") }

    private enum CodingKeys: String, CodingKey {
        case id, title, description, category, coverImage, photos, topics, location, city
        case mapsLink, mode, onlineLink, date, time, startAt, notes, visibility
        case status, cancelReason, capacity, invitees, counts, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try c.decodeIfPresent(String.self, forKey: .description)
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? "SITE_VISIT"
        coverImage = try c.decodeIfPresent(String.self, forKey: .coverImage)
        photos = try c.decodeIfPresent([String].self, forKey: .photos) ?? []
        topics = try c.decodeIfPresent([String].self, forKey: .topics) ?? []
        location = try c.decodeIfPresent(String.self, forKey: .location) ?? ""
        city = try c.decodeIfPresent(String.self, forKey: .city)
        mapsLink = try c.decodeIfPresent(String.self, forKey: .mapsLink)
        mode = try c.decodeIfPresent(String.self, forKey: .mode) ?? "IN_PERSON"
        onlineLink = try c.decodeIfPresent(String.self, forKey: .onlineLink)
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        time = try c.decodeIfPresent(String.self, forKey: .time) ?? ""
        startAt = try c.decodeIfPresent(String.self, forKey: .startAt)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        visibility = try c.decodeIfPresent(String.self, forKey: .visibility) ?? "PUBLIC"
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "SCHEDULED"
        cancelReason = try c.decodeIfPresent(String.self, forKey: .cancelReason)
        capacity = try c.decodeIfPresent(Int.self, forKey: .capacity)
        invitees = try c.decodeIfPresent([CpMeetupInvitee].self, forKey: .invitees) ?? []
        counts = try c.decodeIfPresent(CpMeetupCounts.self, forKey: .counts) ?? CpMeetupCounts()
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }
}

struct CpMeetupCounts: Codable {
    var invited = 0
    var going = 0
    var maybe = 0
    var declined = 0
    var noReply = 0
    var checkedIn = 0
    /// Confirmed attendees plus the guests they are bringing.
    var goingHeads = 0

    init() {}

    private enum CodingKeys: String, CodingKey {
        case invited, going, maybe, declined, noReply, checkedIn, goingHeads
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        invited = try c.decodeIfPresent(Int.self, forKey: .invited) ?? 0
        going = try c.decodeIfPresent(Int.self, forKey: .going) ?? 0
        maybe = try c.decodeIfPresent(Int.self, forKey: .maybe) ?? 0
        declined = try c.decodeIfPresent(Int.self, forKey: .declined) ?? 0
        noReply = try c.decodeIfPresent(Int.self, forKey: .noReply) ?? 0
        checkedIn = try c.decodeIfPresent(Int.self, forKey: .checkedIn) ?? 0
        goingHeads = try c.decodeIfPresent(Int.self, forKey: .goingHeads) ?? 0
    }
}

struct CpMeetupInvitee: Codable, Identifiable {
    let id: Int
    /// INVITED — the organiser added them. DISCOVERY — they found it themselves.
    var source: String = "INVITED"
    var contactId: Int?
    /// Set when this person has a Dealio account, so the invite reaches their app.
    var userId: Int?
    var name: String = ""
    var phone: String = ""
    var email: String?
    /// INVITED | GOING | MAYBE | DECLINED
    var rsvp: String = "INVITED"
    var guests: Int = 0
    var respondedAt: String?
    var checkedInAt: String?

    var foundItThemselves: Bool { source == "DISCOVERY" }
    var isCheckedIn: Bool { checkedInAt != nil }

    private enum CodingKeys: String, CodingKey {
        case id, source, contactId, userId, name, phone, email, rsvp, guests
        case respondedAt, checkedInAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? "INVITED"
        contactId = try c.decodeIfPresent(Int.self, forKey: .contactId)
        userId = try c.decodeIfPresent(Int.self, forKey: .userId)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        phone = try c.decodeIfPresent(String.self, forKey: .phone) ?? ""
        email = try c.decodeIfPresent(String.self, forKey: .email)
        rsvp = try c.decodeIfPresent(String.self, forKey: .rsvp) ?? "INVITED"
        guests = try c.decodeIfPresent(Int.self, forKey: .guests) ?? 0
        respondedAt = try c.decodeIfPresent(String.self, forKey: .respondedAt)
        checkedInAt = try c.decodeIfPresent(String.self, forKey: .checkedInAt)
    }
}

struct CpMeetupInviteePayload: Encodable, Identifiable, Hashable {
    var contactId: Int?
    var name: String
    var phone: String
    var email: String?

    /// Identity is the phone: the same person invited from a contact and typed
    /// in by hand must not appear twice on the list.
    var id: String { phone.filter(\.isNumber) }
}

/// Everyone the organiser could invite — their CRM contacts and the buyers the
/// platform knows about.
struct InvitableResponse: Codable {
    var contacts: [InvitableContact] = []
    var customers: [InvitableCustomer] = []

    init() {}

    private enum CodingKeys: String, CodingKey { case contacts, customers }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        contacts = try c.decodeIfPresent([InvitableContact].self, forKey: .contacts) ?? []
        customers = try c.decodeIfPresent([InvitableCustomer].self, forKey: .customers) ?? []
    }
}

struct InvitableContact: Codable, Identifiable {
    let id: Int
    var name: String = ""
    var phone: String = ""
    var countryCode: String?
    var email: String?
}

struct InvitableCustomer: Codable, Identifiable {
    let id: Int
    var name: String = ""
    var phone: String = ""
    var email: String?
    /// Their preferred city — how the organiser spots who is even local.
    var city: String?
}

struct MeetupPhotoUpload: Codable { var url: String = "" }

// MARK: - The customer's view of a meetup
//
// Deliberately thinner than the organiser's `CpMeetup`: a customer browsing by
// city is a stranger to this event, so the invite list never crosses the wire.

struct CustomerMeetup: Codable, Identifiable {
    let id: Int
    var title: String = ""
    var description: String?
    var category: String = "SITE_VISIT"
    var coverImage: String?
    var photos: [String] = []
    var topics: [String] = []
    var location: String = ""
    var city: String?
    var mapsLink: String?
    var mode: String = "IN_PERSON"
    var onlineLink: String?
    var date: String = ""
    var time: String = ""
    var startAt: String?
    var notes: String?
    var status: String = "SCHEDULED"
    var cancelReason: String?
    var capacity: Int?
    var hostName: String = ""
    /// Only sent when this customer was personally invited.
    var hostPhone: String?
    var hostPhoto: String?
    var hostTier: String?
    var goingCount: Int = 0
    /// The first few names, so the page can say who else is coming.
    var goingNames: [String] = []
    /// True when a partner asked this customer by name, rather than them finding it.
    var invited = false
    /// nil until they answer. INVITED means asked but still silent.
    var myRsvp: String?
    var myGuests: Int = 0

    var isCancelled: Bool { status == "CANCELLED" }
    var isGoing: Bool { myRsvp == "GOING" }
    /// Asked, but has not said yes or no yet.
    var awaitingReply: Bool { invited && (myRsvp == nil || myRsvp == "INVITED") }
    var isFull: Bool { capacity.map { goingCount >= $0 && !isGoing } ?? false }
    var coverURL: URL? { AppConfig.resolveAssetURL(coverImage) }
    var whenText: String { [date, time].filter { !$0.isEmpty }.joined(separator: " · ") }

    private enum CodingKeys: String, CodingKey {
        case id, title, description, category, coverImage, photos, topics, location, city
        case mapsLink, mode, onlineLink, date, time, startAt, notes, status, cancelReason
        case capacity, hostName, hostPhone, hostPhoto, hostTier
        case goingCount, goingNames, invited, myRsvp, myGuests
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try c.decodeIfPresent(String.self, forKey: .description)
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? "SITE_VISIT"
        coverImage = try c.decodeIfPresent(String.self, forKey: .coverImage)
        photos = try c.decodeIfPresent([String].self, forKey: .photos) ?? []
        topics = try c.decodeIfPresent([String].self, forKey: .topics) ?? []
        location = try c.decodeIfPresent(String.self, forKey: .location) ?? ""
        city = try c.decodeIfPresent(String.self, forKey: .city)
        mapsLink = try c.decodeIfPresent(String.self, forKey: .mapsLink)
        mode = try c.decodeIfPresent(String.self, forKey: .mode) ?? "IN_PERSON"
        onlineLink = try c.decodeIfPresent(String.self, forKey: .onlineLink)
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        time = try c.decodeIfPresent(String.self, forKey: .time) ?? ""
        startAt = try c.decodeIfPresent(String.self, forKey: .startAt)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "SCHEDULED"
        cancelReason = try c.decodeIfPresent(String.self, forKey: .cancelReason)
        capacity = try c.decodeIfPresent(Int.self, forKey: .capacity)
        hostName = try c.decodeIfPresent(String.self, forKey: .hostName) ?? ""
        hostPhone = try c.decodeIfPresent(String.self, forKey: .hostPhone)
        hostPhoto = try c.decodeIfPresent(String.self, forKey: .hostPhoto)
        hostTier = try c.decodeIfPresent(String.self, forKey: .hostTier)
        goingCount = try c.decodeIfPresent(Int.self, forKey: .goingCount) ?? 0
        goingNames = try c.decodeIfPresent([String].self, forKey: .goingNames) ?? []
        invited = try c.decodeIfPresent(Bool.self, forKey: .invited) ?? false
        myRsvp = try c.decodeIfPresent(String.self, forKey: .myRsvp)
        myGuests = try c.decodeIfPresent(Int.self, forKey: .myGuests) ?? 0
    }
}

/// What `GET /customer/meetups` answers with — the list, plus the city the
/// server resolved it against so the heading can name it.
struct CustomerMeetupFeed: Codable {
    var city: String?
    var meetups: [CustomerMeetup] = []

    private enum CodingKeys: String, CodingKey { case city, meetups }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        city = try c.decodeIfPresent(String.self, forKey: .city)
        meetups = try c.decodeIfPresent([CustomerMeetup].self, forKey: .meetups) ?? []
    }

    init() {}
}
