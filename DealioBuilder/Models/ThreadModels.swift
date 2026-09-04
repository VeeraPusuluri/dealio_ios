import Foundation

// MARK: - Messaging, for all three portals
//
// A conversation is between *people*. It used to be a room inside a deal, keyed
// (dealId, threadKey) — so a buyer talking to one builder about two towers had
// two "Builder" rows in their inbox, same person behind both.
//
// Role-agnostic: the caller is resolved from the token and the backend decides
// which conversations they may hold, so one API serves the builder, the CP and
// the buyer without any of them passing an id for themselves.

struct ConversationLastMessage: Codable, Hashable {
    var message: String = ""
    var senderRole: String = ""
    var senderName: String = ""
    var createdAt: String = ""

    private enum CodingKeys: String, CodingKey { case message, senderRole, senderName, createdAt }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
        senderRole = try c.decodeIfPresent(String.self, forKey: .senderRole) ?? ""
        senderName = try c.decodeIfPresent(String.self, forKey: .senderName) ?? ""
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }
}

/// One conversation, as both the inbox and the "+" picker see it.
///
/// `id` is nil for a candidate nobody has opened yet; `key` is always present and
/// is what `open` takes, so a screen can hand either to the same call site.
struct Conversation: Codable, Identifiable, Hashable {
    var id: Int?
    var key: String = ""
    /// "cp-customer" | "builder-cp" | "group" | "builder-customer"
    var kind: String = ""
    /// Who the viewer is talking to, already phrased from their side.
    var title: String = ""
    /// The other participants by name — the second line on a group row.
    var participants: [String] = []
    var isGroup: Bool = false
    var lastMessage: ConversationLastMessage?
    var lastMessageAt: String?
    var unreadCount: Int = 0

    /// A stable identity for `ForEach` even before the row is opened.
    var rowID: String { id.map(String.init) ?? key }

    private enum CodingKeys: String, CodingKey {
        case id, key, kind, title, participants, isGroup, lastMessage, lastMessageAt, unreadCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id)
        key = try c.decodeIfPresent(String.self, forKey: .key) ?? ""
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        participants = try c.decodeIfPresent([String].self, forKey: .participants) ?? []
        isGroup = try c.decodeIfPresent(Bool.self, forKey: .isGroup) ?? false
        lastMessage = try c.decodeIfPresent(ConversationLastMessage.self, forKey: .lastMessage)
        lastMessageAt = try c.decodeIfPresent(String.self, forKey: .lastMessageAt)
        unreadCount = try c.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0
    }

    init(id: Int? = nil, key: String = "", kind: String = "", title: String = "",
         participants: [String] = [], isGroup: Bool = false,
         lastMessage: ConversationLastMessage? = nil, lastMessageAt: String? = nil,
         unreadCount: Int = 0) {
        self.id = id; self.key = key; self.kind = kind; self.title = title
        self.participants = participants; self.isGroup = isGroup
        self.lastMessage = lastMessage; self.lastMessageAt = lastMessageAt
        self.unreadCount = unreadCount
    }
}

struct ConversationMessage: Codable, Identifiable, Hashable {
    var id: Int = 0
    var conversationId: Int = 0
    var senderId: Int = 0
    var senderName: String = ""
    var senderRole: String = ""
    var message: String = ""
    var createdAt: String = ""

    private enum CodingKeys: String, CodingKey {
        case id, conversationId, senderId, senderName, senderRole, message, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        conversationId = try c.decodeIfPresent(Int.self, forKey: .conversationId) ?? 0
        senderId = try c.decodeIfPresent(Int.self, forKey: .senderId) ?? 0
        senderName = try c.decodeIfPresent(String.self, forKey: .senderName) ?? ""
        senderRole = try c.decodeIfPresent(String.self, forKey: .senderRole) ?? ""
        message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }
}

struct ConversationTranscript: Codable {
    var conversation: Conversation = Conversation()
    var messages: [ConversationMessage] = []

    private enum CodingKeys: String, CodingKey { case conversation, messages }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        conversation = try c.decodeIfPresent(Conversation.self, forKey: .conversation) ?? Conversation()
        messages = try c.decodeIfPresent([ConversationMessage].self, forKey: .messages) ?? []
    }
}

struct NudgeResult: Codable {
    var nudged: [String] = []
    var action: String = ""

    private enum CodingKeys: String, CodingKey { case nudged, action }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nudged = try c.decodeIfPresent([String].self, forKey: .nudged) ?? []
        action = try c.decodeIfPresent(String.self, forKey: .action) ?? ""
    }
}

// MARK: - Service

/// Conversations, for whichever portal is asking.
///
/// Role-agnostic by design — the backend resolves the caller from the token and
/// decides which conversations they may hold, so the builder, CP and customer
/// shells all share this one service.
enum ThreadService {
    private struct OpenRequest: Encodable { let key: String }
    private struct SendRequest: Encodable { let message: String }

    /// The inbox: conversations that have actually been opened.
    static func list() async throws -> [Conversation] {
        try await APIClient.shared.get("/threads")
    }

    /// Everyone this user could talk to — what the "+" picker offers.
    static func candidates() async throws -> [Conversation] {
        try await APIClient.shared.get("/threads/candidates")
    }

    /// Open or resume a conversation. Safe to call twice; the key is the identity.
    static func open(key: String) async throws -> Conversation {
        try await APIClient.shared.post("/threads/open", body: OpenRequest(key: key))
    }

    static func messages(conversationId: Int) async throws -> ConversationTranscript {
        try await APIClient.shared.get("/threads/\(conversationId)/messages")
    }

    static func send(conversationId: Int, message: String) async throws -> ConversationMessage {
        try await APIClient.shared.post("/threads/\(conversationId)/messages",
                                        body: SendRequest(message: message))
    }

    /// Mark one conversation read up to now. Best-effort by design: a failure here
    /// costs a stale badge, never a lost message.
    static func markRead(conversationId: Int) async {
        try? await APIClient.shared.postVoid("/threads/\(conversationId)/read")
    }

    /// Nudge whoever the deal is waiting on. Worth surfacing, unlike `markRead`:
    /// a 429 carries the cooldown message the user should read.
    static func nudge(dealId: Int) async throws -> NudgeResult {
        try await APIClient.shared.post("/deals/\(dealId)/nudge")
    }
}

// MARK: - Relative time

/// "now" / "12m" / "5h" / "3d" / "7 Aug" from an ISO-8601 timestamp.
///
/// An inbox needs finer granularity than the ledger's day slicing: "3d" and "12m"
/// are the difference between a stale thread and a live one.
func shortAgo(_ iso: String?) -> String {
    guard let then = ISO8601.parse(iso) else { return "" }
    let minutes = Int(Date().timeIntervalSince(then) / 60)
    switch minutes {
    case ..<1: return "now"
    case ..<60: return "\(minutes)m"
    case ..<(60 * 24): return "\(minutes / 60)h"
    case ..<(60 * 24 * 7): return "\(minutes / (60 * 24))d"
    default:
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: then)
    }
}

/// ISO-8601 parsing that tolerates the two shapes the backend emits: a full
/// instant with a `Z`, and a bare `yyyy-MM-dd'T'HH:mm:ss` in UTC.
enum ISO8601 {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain = ISO8601DateFormatter()
    private static let naive: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func parse(_ iso: String?) -> Date? {
        guard let iso, !iso.isEmpty else { return nil }
        return withFraction.date(from: iso)
            ?? plain.date(from: iso)
            ?? naive.date(from: String(iso.prefix(19)))
    }
}
