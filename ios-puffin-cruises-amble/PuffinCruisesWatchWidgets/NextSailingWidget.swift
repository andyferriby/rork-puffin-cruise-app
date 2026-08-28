import WidgetKit
import SwiftUI

nonisolated struct WidgetSailing: Identifiable, Hashable {
    let time: String
    let cruiseName: String
    let cruiseEmoji: String
    let date: Date

    var id: String { "\(time)-\(cruiseName)" }
}

/// Standalone schedule fetch for the widget extension — talks to Supabase
/// REST directly with the public URL and publishable anon key.
nonisolated enum WidgetScheduleFetch {
    private static let supabaseURL = "https://hizgugsvbkzjrjsaaxkd.supabase.co"
    private static let anonKey = "sb_publishable_g6zekmj_iMcihX5nycHKJQ_x8lCRnhW"

    static func nextSailing(after date: Date = .now) async -> WidgetSailing? {
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

        struct ConfigRow: Decodable { let value: Payload }
        struct Payload: Decodable {
            let cruises: [Cruise]
            let days: [Day]
        }
        struct Cruise: Decodable { let id: String; let name: String; let emoji: String? }
        struct Day: Decodable { let date: String; let times: [Slot] }
        struct Slot: Decodable { let time: String; let cruiseId: String }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let rows = try JSONDecoder().decode([ConfigRow].self, from: data)
            guard let config = rows.first?.value else { return nil }

            let cruises = Dictionary(uniqueKeysWithValues: config.cruises.map { ($0.id, $0) })
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "Europe/London")
            formatter.dateFormat = "yyyy-MM-dd HH:mm"

            let candidates = config.days.flatMap { day in
                day.times.compactMap { slot -> WidgetSailing? in
                    guard let cruise = cruises[slot.cruiseId],
                          let sailDate = formatter.date(from: "\(day.date) \(slot.time)") else {
                        return nil
                    }
                    return WidgetSailing(
                        time: slot.time,
                        cruiseName: cruise.name,
                        cruiseEmoji: cruise.emoji ?? "⛵️",
                        date: sailDate
                    )
                }
            }
            return candidates
                .filter { $0.date > date }
                .min { $0.date < $1.date }
        } catch {
            print("[widget-schedule] fetch failed: \(error.localizedDescription)")
            return nil
        }
    }
}

nonisolated struct WidgetSailingEntry: TimelineEntry {
    let date: Date
    let sailing: WidgetSailing?
    let isStale: Bool
}

nonisolated struct SailingTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetSailingEntry {
        WidgetSailingEntry(
            date: .now,
            sailing: WidgetSailing(
                time: "14:30",
                cruiseName: "Puffin & Seal Cruise",
                cruiseEmoji: "⛵️",
                date: .now.addingTimeInterval(5400)
            ),
            isStale: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetSailingEntry) -> Void) {
        Task {
            completion(await Self.makeEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetSailingEntry>) -> Void) {
        Task {
            if let sailing = await WidgetScheduleFetch.nextSailing() {
                let entry = WidgetSailingEntry(date: .now, sailing: sailing, isStale: false)
                // Refresh shortly after the sailing departs so the next one takes over.
                completion(Timeline(entries: [entry], policy: .after(sailing.date.addingTimeInterval(900))))
            } else {
                let entry = WidgetSailingEntry(date: .now, sailing: nil, isStale: true)
                completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3600))))
            }
        }
    }

    @MainActor
    private static func makeEntry() async -> WidgetSailingEntry {
        let sailing = await WidgetScheduleFetch.nextSailing()
        return WidgetSailingEntry(date: .now, sailing: sailing, isStale: sailing == nil)
    }
}

// MARK: - Views

struct SailingEntryView: View {
    var entry: SailingTimelineProvider.Entry

    var body: some View {
        Group {
            if let sailing = entry.sailing, !entry.isStale {
                nextSailingBody(sailing)
            } else {
                staleBody
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private func nextSailingBody(_ sailing: WidgetSailing) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "sailboat.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.25))
                Text("NEXT SAILING")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white.opacity(0.7))
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(sailing.time)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(timerInterval: entry.date...sailing.date, countsDown: true)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.35, green: 0.8, blue: 0.7))
            }
            Text("\(sailing.cruiseEmoji) \(sailing.cruiseName)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var staleBody: some View {
        HStack(spacing: 5) {
            Image(systemName: "sailboat")
                .foregroundStyle(.secondary)
            Text("No sailings scheduled")
                .font(.system(size: 12, weight: .semibold))
        }
    }
}

/// Compact circular complication: boat glyph with a live countdown underneath.
struct SailingCircularView: View {
    var entry: SailingTimelineProvider.Entry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let sailing = entry.sailing, !entry.isStale {
                VStack(spacing: 0) {
                    Image(systemName: "sailboat.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.25))
                    Text(timerInterval: entry.date...sailing.date, countsDown: true)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 4)
            } else {
                Image(systemName: "sailboat.slash")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Corner complication: departure time as the big glyph text.
struct SailingCornerView: View {
    var entry: SailingTimelineProvider.Entry

    var body: some View {
        if let sailing = entry.sailing, !entry.isStale {
            Text(sailing.time)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .widgetLabel("Sailing \(sailing.cruiseName)")
        } else {
            Image(systemName: "sailboat.slash")
                .widgetLabel("No sailings")
        }
    }
}

struct SailingInlineView: View {
    var entry: SailingTimelineProvider.Entry

    var body: some View {
        if let sailing = entry.sailing, !entry.isStale {
            Text("⛵ \(sailing.time) in ") + Text(timerInterval: entry.date...sailing.date, countsDown: true)
        } else {
            Text("No sailings")
        }
    }
}

// MARK: - Widget

struct NextSailingWidget: Widget {
    let kind: String = "PuffinCruisesSailingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SailingTimelineProvider()) { entry in
            SailingEntryView(entry: entry)
        }
        .configurationDisplayName("Next Sailing")
        .description("Countdown to Puffin Cruises' next departure, live on your watch face.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}
