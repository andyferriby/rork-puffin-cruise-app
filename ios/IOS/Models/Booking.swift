import Foundation

struct Booking: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let cruiseId: String?
    let cruiseName: String
    let cruiseDate: String
    let cruiseTime: String
    let adults: Int
    let children: Int
    let customerName: String
    let customerEmail: String
    let customerPhone: String?
    let amountTotal: Int
    let currency: String
    let status: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case cruiseId = "cruise_id"
        case cruiseName = "cruise_name"
        case cruiseDate = "cruise_date"
        case cruiseTime = "cruise_time"
        case adults, children
        case customerName = "customer_name"
        case customerEmail = "customer_email"
        case customerPhone = "customer_phone"
        case amountTotal = "amount_total"
        case currency, status
        case createdAt = "created_at"
    }

    var isPaid: Bool { status == "paid" || status == "checked_in" }
    var isCheckedIn: Bool { status == "checked_in" }
    var totalPounds: Double { Double(amountTotal) / 100.0 }
    var passengerSummary: String {
        let a = "\(adults) adult" + (adults == 1 ? "" : "s")
        let c = children > 0 ? ", \(children) child" + (children == 1 ? "" : "ren") : ""
        return a + c
    }
}

struct CreateCheckoutBody: Codable, Sendable {
    let cruiseId: String
    let cruiseName: String
    let date: String
    let time: String
    let adults: Int
    let children: Int
    let customerName: String
    let customerEmail: String
    let customerPhone: String

    enum CodingKeys: String, CodingKey {
        case cruiseId, cruiseName, date, time, adults, children
        case customerName, customerEmail, customerPhone
    }
}

struct CreateCheckoutResponse: Codable, Sendable {
    let url: String
    let bookingId: String
}
