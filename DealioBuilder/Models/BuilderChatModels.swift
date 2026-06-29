import Foundation

/// A single chat message on a deal — `builder/:id/deals/:dealId` → messages[].
struct DealMessage: Codable, Identifiable {
    let id: Int
    let senderRole: String?
    let message: String
    let createdAt: String?
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
