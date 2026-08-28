import Foundation
import WidgetKit

nonisolated struct WidgetTideEvent: Identifiable, Hashable {
    let date: Date
    let isHigh: Bool
    let height: Double

    var id: Date { date }
    var label: String { isHigh ? "High" : "Low" }
}

/// Standalone tide fetch for the widget extension (it cannot import the
/// watch app's TideFetch). Same Open-Meteo marine API, Amble Harbour.
nonisolated enum WidgetTideFetch {
    private static let baseURL = "https://marine-api.open-meteo.com/v1/marine"

    static func fetchEvents() async -> [WidgetTideEvent] {
        guard var components = URLComponents(string: baseURL) else { return [] }
        components.queryItems = [
            URLQueryItem(name: "latitude", value: "55.3338"),
            URLQueryItem(name: "longitude", value: "-1.5803"),
            URLQueryItem(name: "hourly", value: "sea_level_height_msl"),
            URLQueryItem(name: "timezone", value: "Europe/London"),
            URLQueryItem(name: "past_days", value: "1"),
            URLQueryItem(name: "forecast_days", value: "3")
        ]
        guard let url = components.url else { return [] }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            struct Response: Decodable {
                struct Hourly: Decodable {
                    let time: [String]
                    let sea_level_height_msl: [Double?]
                }
                let hourly: Hourly
            }
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            return parse(times: decoded.hourly.time, heights: decoded.hourly.sea_level_height_msl)
        } catch {
            print("[widget-tides] fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    nonisolated static func parse(times: [String], heights: [Double?]) -> [WidgetTideEvent] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

        let series = zip(times, heights).compactMap { time, height -> (Date, Double)? in
            guard let height, let date = formatter.date(from: time) else { return nil }
            return (date, height)
        }
        guard series.count > 2 else { return [] }

        var events: [WidgetTideEvent] = []
        for index in 1..<(series.count - 1) {
            let previous = series[index - 1].1
            let current = series[index].1
            let next = series[index + 1].1
            let isHigh = current >= previous && current > next
            let isLow = current <= previous && current < next
            if isHigh || isLow {
                events.append(WidgetTideEvent(date: series[index].0, isHigh: isHigh, height: current))
            }
        }
        return events
    }

    nonisolated static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

nonisolated struct WidgetTideEntry: TimelineEntry {
    let date: Date
    let nextTide: WidgetTideEvent?
    let isStale: Bool
}
