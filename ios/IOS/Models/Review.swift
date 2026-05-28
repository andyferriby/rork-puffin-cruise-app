import Foundation

struct Review: Codable, Identifiable, Sendable {
    let id: String
    let bookingId: String
    let cruiseId: String
    let cruiseName: String
    let rating: Int
    let comment: String?
    let guestName: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case bookingId = "booking_id"
        case cruiseId = "cruise_id"
        case cruiseName = "cruise_name"
        case rating, comment
        case guestName = "guest_name"
        case createdAt = "created_at"
    }
}

struct ReviewInsert: Codable {
    let bookingId: String
    let cruiseId: String
    let cruiseName: String
    let rating: Int
    let comment: String?
    let guestName: String?

    enum CodingKeys: String, CodingKey {
        case bookingId = "booking_id"
        case cruiseId = "cruise_id"
        case cruiseName = "cruise_name"
        case rating, comment
        case guestName = "guest_name"
    }
}

struct CruiseRating: Codable, Sendable {
    let cruiseId: String
    let averageRating: Double
    let reviewCount: Int

    enum CodingKeys: String, CodingKey {
        case cruiseId = "cruise_id"
        case averageRating = "avg_rating"
        case reviewCount = "count"
    }
}
