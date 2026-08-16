import Foundation

/// Per-thread unread counts, read markers, and the nudge.
///
/// Role-agnostic: the caller is resolved from the token and the backend
/// authorizes every (dealId, threadKey) pair with the same rule that decides
/// whether the thread is readable at all. One service serves all three portals.

/// Identifies one thread on one deal. Doubles as the dictionary key callers use
/// to look a summary back up, so there is no hand-rolled `"\(id):\(key)"` string
/// to get wrong.
struct ThreadRef: Codable, Hashable {
    let dealId: Int
    let threadKey: String
}

struct ThreadLastMessage: Codable, Hashable {
    var message: String?
    var senderRole: String?
    var senderName: String?
    var createdAt: String?
}

struct ThreadSummary: Codable, Hashable {
    let dealId: Int
    let threadKey: String
    var lastMessage: ThreadLastMessage?
    var unreadCount: Int?

    var ref: ThreadRef { ThreadRef(dealId: dealId, threadKey: threadKey) }
    var unread: Int { unreadCount ?? 0 }
}

/// Result of `POST /deals/:id/nudge`.
struct NudgeResult: Codable {
    var nudged: [String]?
    var action: String?
}

enum ThreadService {
    private struct SummaryRequest: Encodable { let threads: [ThreadRef] }
    private struct ReadRequest: Encodable { let dealId: Int; let threadKey: String }
    private struct Empty: Encodable {}

    /// The backend caps a summary request at 200 pairs; stop short rather than
    /// be silently truncated.
    private static let maxThreads = 200

    /// Unread counts and last messages for the given threads, in one request.
    /// Unauthorized pairs are simply absent from the result.
    static func summaries(_ refs: [ThreadRef]) async -> [ThreadRef: ThreadSummary] {
        guard !refs.isEmpty else { return [:] }
        let body = SummaryRequest(threads: Array(refs.prefix(maxThreads)))
        do {
            let list: [ThreadSummary] = try await APIClient.shared.post("/threads/summary", body: body)
            return Dictionary(list.map { ($0.ref, $0) }, uniquingKeysWith: { _, latest in latest })
        } catch {
            // A failed summary costs a badge, never a message. Callers render
            // the threads they already know about with no counts on them.
            return [:]
        }
    }

    /// Marks one thread read up to now.
    ///
    /// Best-effort by design: a failure here costs a stale badge, so callers
    /// fire it without surfacing errors.
    static func markRead(dealId: Int, threadKey: String) async {
        try? await APIClient.shared.call(
            "/threads/read",
            body: ReadRequest(dealId: dealId, threadKey: threadKey)
        )
    }

    /// Nudges whoever the deal is waiting on. The target is derived server-side
    /// from the deal's own baton, so there is nothing to send but the deal id.
    ///
    /// Unlike `markRead` this is worth surfacing: the caller wants to know it
    /// landed, and a 429 carries the cooldown message the user should read.
    static func nudge(dealId: Int) async throws -> NudgeResult {
        try await APIClient.shared.post("/deals/\(dealId)/nudge", body: Empty())
    }
}
