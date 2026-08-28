import Foundation
import Observation

/// Fetches sunset times for Amble from Open-Meteo (same source as the iPhone
/// app's Golden Hour Club) and derives the "golden hour" — the 40 minutes
/// before sunset, when the light over Coquet Island is at its best.
nonisolated enum SunsetFetch {
    static func fetchGoldenHour() async -> Date? {
        guard var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "latitude", value: "55.3338"),
            URLQueryItem(name: "longitude", value: "-1.5803"),
            URLQueryItem(name: "daily", value: "sunset"),
            URLQueryItem(name: "timezone", value: "Europe/London"),
            URLQueryItem(name: "forecast_days", value: "2")
        ]
        guard let url = components.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            struct Response: Decodable {
                struct Daily: Decodable { let sunset: [String] }
                let daily: Daily
            }
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "Europe/London")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            return decoded.daily.sunset
                .compactMap { formatter.date(from: $0) }
                .compactMap { $0.addingTimeInterval(-40 * 60) }
                .first { $0 > Date() }
        } catch {
            print("[sunset] fetch failed: \(error.localizedDescription)")
            return nil
        }
    }
}

/// Caches today's golden hour for the whole day so the home screen never
/// refetches it on every visit.
@MainActor
@Observable
final class GoldenHourModel {
    private(set) var goldenHour: Date?

    func load() async {
        let defaults = UserDefaults.standard
        let dayKey = Self.dayString(Date())
        if defaults.string(forKey: "goldenHourDay") == dayKey,
           let stored = defaults.object(forKey: "goldenHourDate") as? Date,
           stored > Date() {
            goldenHour = stored
            return
        }

        let date = await SunsetFetch.fetchGoldenHour()
        goldenHour = date
        if let date {
            defaults.set(dayKey, forKey: "goldenHourDay")
            defaults.set(date, forKey: "goldenHourDate")
        }
    }

    nonisolated private static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
