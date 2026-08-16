import Foundation

/// A single chat message on a deal — `builder/:id/deals/:dealId` → messages[].
struct DealMessage: Codable, Identifiable {
    let id: Int
    let senderRole: String?
    var senderName: String?
    let message: String
    let createdAt: String?
    /// Which private thread this belongs to: `builder-cp` | `builder-customer` |
    /// `cp-customer` | `group`. The backend only ever sends threads this caller
    /// is party to; this is what the party rail switches on. Legacy rows default
    /// to `builder-customer`, matching the column default.
    var threadKey: String?

    var thread: String { threadKey ?? "builder-customer" }
}

/// One entry in a deal's ledger.
///
/// `summary` is written server-side for a reader, so the client renders it as-is
/// rather than re-deriving phrasing from `type`.
struct DealEvent: Codable, Identifiable {
    let id: Int
    var type: String?
    var actorRole: String?
    var actorName: String?
    var summary: String?
    var createdAt: String?
}

/// Full deal detail including the chat thread — `builder/:id/deals/:dealId`.
struct DealDetail: Codable, Identifiable {
    let id: Int
    let status: String?
    let dealValue: Double?
    let customerName: String?
    let customerPhone: String?
    let projectName: String?
    let messages: [DealMessage]?
    let paymentSchedule: [Installment]?
    // The deal flow reads these: who else is on the deal, whether each side has
    // agreed, and when it last moved.
    var cpName: String?
    var cpPhone: String?
    var builderName: String?
    var cpAgreed: Bool?
    var customerConfirmed: Bool?
    var createdAt: String?
    var updatedAt: String?
    var events: [DealEvent]?

    var hasCp: Bool { !(cpName ?? "").isEmpty }
    /// Days since the deal last moved, for the spine's stalled styling.
    var idleDays: Int? { daysSince(updatedAt ?? createdAt) }
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

/// A builder notification — `builder/notifications`.
struct BuilderNotification: Codable, Identifiable {
    let id: Int
    let title: String?
    let message: String?
    let type: String?
    let read: Bool?
    let createdAt: String?
}

/// Body for creating a project — `POST builder/:id/projects`.
struct ProjectPayload: Encodable {
    let name: String
    let city: String?
    let locality: String?
    let projectType: String?
    let status: String?
    let totalUnits: Int?
    let priceMin: Double?
    let priceMax: Double?
    let reraNumber: String?
    let possessionDate: String?
}
