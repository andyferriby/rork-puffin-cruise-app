import Foundation

struct NotificationRecord: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let body: String
    let sentAt: String
    let recipientCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case sentAt = "sent_at"
        case recipientCount = "recipient_count"
    }
}
