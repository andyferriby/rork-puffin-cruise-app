import Foundation

nonisolated struct TideEvent: Identifiable, Hashable {
    let date: Date
    let isHigh: Bool
    let height: Double

    var id: Date { date }
    var label: String { isHigh ? "High" : "Low" }
    var symbolName: String { isHigh ? "arrow.up.to.line" : "arrow.down.to.line" }
}

/// Fetches tide data for Amble Harbour from Open-Meteo's free marine API
/// (hourly sea level including tides) and derives high/low water events.
nonisolated enum TideFetch {
    private static let baseURL = "https://marine-api.open-meteo.com/v1/marine"
    private static let ambleLatitude = "55.3338"
    private static let ambleLongitude = "-1.5803"

    static func fetchEvents() async -> [TideEvent] {
        guard var components = URLComponents(string: baseURL) else { return [] }
        components.queryItems = [
            URLQueryItem(name: "latitude", value: ambleLatitude),
            URLQueryItem(name: "longitude", value: ambleLongitude),
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
            print("[tides] fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Finds local maxima/minima in the hourly sea-level series.
    nonisolated static func parse(times: [String], heights: [Double?]) -> [TideEvent] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

        let series = zip(times, heights).compactMap { time, height -> (Date, Double)? in
            guard let height, let date = formatter.date(from: time) else { return nil }
            return (date, height)
        }
        guard series.count > 2 else { return [] }

        var events: [TideEvent] = []
        for index in 1..<(series.count - 1) {
            let previous = series[index - 1].1
            let current = series[index].1
            let next = series[index + 1].1
            let isHigh = current >= previous && current > next
            let isLow = current <= previous && current < next
            if isHigh || isLow {
                events.append(TideEvent(date: series[index].0, isHigh: isHigh, height: current))
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
