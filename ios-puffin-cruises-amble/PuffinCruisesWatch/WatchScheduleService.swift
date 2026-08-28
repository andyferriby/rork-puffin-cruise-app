import Foundation
import Observation

/// Minimal schedule fetch for the watch app — talks to Supabase REST directly
/// using the public project URL and publishable anon key.
nonisolated enum WatchScheduleService {
    private static let supabaseURL = "https://hizgugsvbkzjrjsaaxkd.supabase.co"
    private static let anonKey = "sb_publishable_g6zekmj_iMcihX5nycHKJQ_x8lCRnhW"

    static func fetchSchedule() async -> WatchScheduleConfig? {
        guard var components = URLComponents(string: "\(supabaseURL)/rest/v1/app_config") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "select", value: "value"),
            URLQueryItem(name: "key", value: "eq.schedule")
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            struct ConfigRow: Decodable { let value: WatchScheduleConfig }
            return try JSONDecoder().decode([ConfigRow].self, from: data).first?.value
        } catch {
            print("[watch-schedule] fetch failed: \(error.localizedDescription)")
            return nil
        }
    }
}

@MainActor
@Observable
final class WatchScheduleModel {
    private(set) var todaysSailings: [WatchSailing] = []
    private(set) var nextSailing: WatchSailing?
    private(set) var nextSailingDate: Date?
    private(set) var isLoading = false
    private(set) var loadFailed = false

    func load() async {
        isLoading = true
        defer { isLoading = false }

        guard let config = await WatchScheduleService.fetchSchedule() else {
            loadFailed = true
            return
        }
        loadFailed = false

        let cruises = Dictionary(
            uniqueKeysWithValues: config.cruises.map { ($0.id, $0) }
        )

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let today = dayFormatter.string(from: Date())

        guard let todaySchedule = config.days.first(where: { $0.date == today }) else {
            todaysSailings = []
            nextSailing = nil
            nextSailingDate = nil
            return
        }

        let sailings = todaySchedule.times
            .sorted { $0.time < $1.time }
            .compactMap { time -> WatchSailing? in
                guard let cruise = cruises[time.cruiseId] else { return nil }
                return WatchSailing(
                    time: time.time,
                    cruiseName: cruise.name,
                    cruiseEmoji: cruise.emoji ?? "⛵️"
                )
            }
        todaysSailings = sailings

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let upcoming = sailings
            .compactMap { sailing -> (WatchSailing, Date)? in
                guard let date = timeFormatter.date(from: "\(today) \(sailing.time)") else {
                    return nil
                }
                return date > Date() ? (sailing, date) : nil
            }
            .min { $0.1 < $1.1 }

        nextSailing = upcoming?.0
        nextSailingDate = upcoming?.1
    }
}
