import Foundation

struct GalleryPhoto: Codable, Identifiable, Sendable {
    let id: String
    let imageURL: String
    let caption: String?
    let guestName: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case imageURL = "image_url"
        case caption
        case guestName = "guest_name"
        case createdAt = "created_at"
    }
}
