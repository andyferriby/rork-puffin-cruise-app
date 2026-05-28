import Foundation

struct ScheduleConfig: Codable, Sendable {
    let version: Int
    var notice: String?
    var contactPhone: String
    var bookingOffice: String
    var cruises: [Cruise]
    var days: [DaySchedule]

    static let `default` = ScheduleConfig(
        version: 1,
        notice: "All sailing times are subject to tide and sea conditions.",
        contactPhone: "07752 861914",
        bookingOffice: "Amble Harbour Village",
        cruises: [
            Cruise(
                id: "puffin-1h",
                name: "1 Hour Puffin Cruise",
                duration: "1 hour",
                description: "Get up close with the puffins of Coquet Island.",
                adultPrice: 18,
                childPrice: 10,
                capacity: 30,
                emoji: "🐧"
            ),
            Cruise(
                id: "seal",
                name: "Seal Watching Cruise",
                duration: "1.5 hours",
                description: "Cruise the coast to spot our local grey seal colony.",
                adultPrice: 22,
                childPrice: 12,
                capacity: 30,
                emoji: "🦭"
            ),
        ],
        days: [
            DaySchedule(
                date: ISO8601DateFormatter().string(from: Date()).prefix(10).description,
                weather: "Sunny, light breeze",
                times: [
                    SailingTime(time: "10:30", cruiseId: "puffin-1h"),
                    SailingTime(time: "11:30", cruiseId: "puffin-1h"),
                    SailingTime(time: "12:30", cruiseId: "puffin-1h"),
                    SailingTime(time: "13:30", cruiseId: "seal"),
                    SailingTime(time: "14:30", cruiseId: "puffin-1h"),
                ]
            ),
        ]
    )
}

struct Cruise: Codable, Identifiable, Sendable {
    let id: String
    var name: String
    var duration: String
    var description: String
    var adultPrice: Int
    var childPrice: Int
    var capacity: Int
    var emoji: String
}

struct DaySchedule: Codable, Identifiable, Sendable {
    var date: String
    var weather: String?
    var times: [SailingTime]

    var id: String { date }
}

struct SailingTime: Codable, Sendable {
    var time: String
    var cruiseId: String
    var note: String?
}
