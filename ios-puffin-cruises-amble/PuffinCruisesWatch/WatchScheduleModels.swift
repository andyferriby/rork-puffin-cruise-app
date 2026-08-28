import Foundation

nonisolated struct WatchCruise: Decodable, Hashable {
    let id: String
    let name: String
    let emoji: String?
}

nonisolated struct WatchSailingTime: Decodable, Hashable {
    let time: String
    let cruiseId: String
}

nonisolated struct WatchDaySchedule: Decodable, Hashable {
    let date: String
    let times: [WatchSailingTime]
}

nonisolated struct WatchScheduleConfig: Decodable, Hashable {
    let cruises: [WatchCruise]
    let days: [WatchDaySchedule]
}

nonisolated struct WatchSailing: Identifiable, Hashable {
    let time: String
    let cruiseName: String
    let cruiseEmoji: String

    var id: String { "\(time)-\(cruiseName)" }
}
