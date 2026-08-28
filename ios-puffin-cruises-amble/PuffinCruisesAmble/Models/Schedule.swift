import Foundation

nonisolated struct Cruise: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var duration: String
    var description: String
    var adultPrice: Double
    var childPrice: Double
    var capacity: Int
    var emoji: String
}

nonisolated struct SailingTime: Codable, Hashable, Identifiable {
    var time: String
    var cruiseId: String
    var note: String?

    var id: String { "\(time)-\(cruiseId)" }
}

nonisolated struct DaySchedule: Codable, Identifiable, Hashable {
    var date: String
    var weather: String?
    var times: [SailingTime]

    var id: String { date }
    var parsedDate: Date { DateFormat.parseISODate(date) ?? Date() }
}

nonisolated struct ScheduleConfig: Codable, Hashable {
    var version: Int
    var notice: String?
    var contactPhone: String
    var bookingOffice: String
    var cruises: [Cruise]
    var days: [DaySchedule]

    static let fallback = ScheduleConfig(
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
            )
        ],
        days: [
            DaySchedule(
                date: {
                    let f = DateFormatter()
                    f.locale = Locale(identifier: "en_US_POSIX")
                    f.dateFormat = "yyyy-MM-dd"
                    return f.string(from: Date())
                }(),
                weather: "Sunny, light breeze",
                times: [
                    SailingTime(time: "10:30", cruiseId: "puffin-1h", note: nil),
                    SailingTime(time: "11:30", cruiseId: "puffin-1h", note: nil),
                    SailingTime(time: "12:30", cruiseId: "puffin-1h", note: nil),
                    SailingTime(time: "13:30", cruiseId: "seal", note: nil),
                    SailingTime(time: "14:30", cruiseId: "puffin-1h", note: nil)
                ]
            )
        ]
    )
}

nonisolated struct BoatLocation: Codable, Hashable {
    var latitude: Double
    var longitude: Double
    var accuracy: Double?
    var heading: Double?
    var speed: Double?
    var updatedAt: String
    var isTracking: Bool
    /// When true, crew has hidden the live position from customer apps (private charter).
    var isHidden: Bool?
}

nonisolated struct CameraVideo: Codable, Identifiable, Hashable {
    var id: String
    var label: String
}

nonisolated struct CamerasConfig: Codable, Hashable {
    var videos: [CameraVideo]
}

nonisolated struct PreprintedBoarding: Codable, Hashable {
    var count: Int
    var lastScanAt: String?
}
