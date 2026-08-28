import Foundation

/// Tide event derived from Open-Meteo's marine API for Amble Harbour.
nonisolated struct TideEvent: Identifiable, Hashable {
    let date: Date
    let isHigh: Bool
    let height: Double

    var id: Date { date }
    var label: String { isHigh ? "High" : "Low" }
}

/// Today's sunset (and derived golden-hour) information.
nonisolated struct SunInfo: Hashable {
    let sunset: Date
}

/// Environment data for the Coast Secrets + Golden Hour features.
/// Same Open-Meteo endpoints the Watch app uses for tides; sunset comes from
/// the free forecast API's daily `sunset` field.
nonisolated enum AmbleConditions {
    private static let ambleLatitude = "55.3338"
    private static let ambleLongitude = "-1.5803"

    static func fetchTides() async -> [TideEvent] {
        guard var components = URLComponents(string: "https://marine-api.open-meteo.com/v1/marine") else {
            return []
        }
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
            return parseTides(times: decoded.hourly.time, heights: decoded.hourly.sea_level_height_msl)
        } catch {
            print("[conditions] tide fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Finds local maxima/minima in the hourly sea-level series.
    nonisolated static func parseTides(times: [String], heights: [Double?]) -> [TideEvent] {
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

    static func fetchSunset() async -> SunInfo? {
        guard var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "latitude", value: ambleLatitude),
            URLQueryItem(name: "longitude", value: ambleLongitude),
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
            let upcoming = decoded.daily.sunset.compactMap { formatter.date(from: $0) }.first { $0 > Date() }
            guard let sunset = upcoming else { return nil }
            return SunInfo(sunset: sunset)
        } catch {
            print("[conditions] sunset fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    nonisolated static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    nonisolated static func shortTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    nonisolated static func dayNumber(_ date: Date) -> Int {
        Calendar(identifier: .gregorian).ordinality(of: .day, in: .year, for: date) ?? 0
    }
}
