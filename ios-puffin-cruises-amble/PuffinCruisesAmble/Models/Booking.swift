import Foundation

nonisolated struct Booking: Codable, Identifiable, Hashable {
    let id: String
    var customer_name: String?
    var cruise_name: String
    var cruise_date: String
    var cruise_time: String
    var adults: Int
    var children: Int
    var customer_email: String?
    var status: String

    var displayDate: String {
        guard let date = DateFormat.parseISODate(cruise_date) else { return cruise_date }
        return DateFormat.shortDay(date)
    }

    var isBoarded: Bool { status == "boarded" }
}

nonisolated struct MembershipPass: Codable, Hashable {
    var memberId: String
    var email: String
    var active: Bool
    var creditsTotal: Int
    var creditsUsed: Int
    var creditsRemaining: Int
    var expiresAt: String
    var discountPercent: Int
    var updatedAt: String?

    var expiryDisplay: String {
        guard let date = ISO8601DateFormatter().date(from: expiresAt)
            ?? DateFormat.parseISODate(String(expiresAt.prefix(10))) else { return expiresAt }
        return DateFormat.numeric(date)
    }
}

nonisolated struct GalleryPhoto: Codable, Identifiable, Hashable {
    let id: String
    var image_url: String
    var caption: String?
    var guest_name: String?
    var created_at: String?
}

nonisolated struct ShopProduct: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    var permalink: String
    var price: String
    var on_sale: Bool
    var stock_status: String
    var images: [ShopImage]
    var short_description: String

    var imageURL: URL? {
        guard let src = images.first?.src else { return nil }
        return URL(string: src)
    }
}

nonisolated struct ShopImage: Codable, Hashable {
    var src: String
    var alt: String?
}
