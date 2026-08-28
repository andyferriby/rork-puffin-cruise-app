import WidgetKit
import SwiftUI

nonisolated struct TideTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetTideEntry {
        WidgetTideEntry(
            date: .now,
            nextTide: WidgetTideEvent(
                date: .now.addingTimeInterval(5400),
                isHigh: true,
                height: 4.6
            ),
            isStale: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetTideEntry) -> Void) {
        Task {
            let entry = await Self.makeEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetTideEntry>) -> Void) {
        Task {
            let events = await WidgetTideFetch.fetchEvents()
            var entries: [WidgetTideEntry] = []

            // One entry per upcoming tide, plus a stale marker after the last.
            let upcoming = events.filter { $0.date > Date.now }
            for tide in upcoming.prefix(8) {
                entries.append(WidgetTideEntry(date: min(Date.now, tide.date), nextTide: tide, isStale: false))
            }

            if let last = upcoming.first {
                let lastEntry = WidgetTideEntry(date: last.date, nextTide: nil, isStale: true)
                entries.append(lastEntry)
                completion(Timeline(entries: entries, policy: .after(last.date.addingTimeInterval(1800))))
            } else {
                entries = [WidgetTideEntry(date: .now, nextTide: nil, isStale: true)]
                completion(Timeline(entries: entries, policy: .after(Date.now.addingTimeInterval(1800))))
            }
        }
    }

    @MainActor
    private static func makeEntry() async -> WidgetTideEntry {
        let events = await WidgetTideFetch.fetchEvents()
        let next = events.first { $0.date > Date.now }
        return WidgetTideEntry(date: .now, nextTide: next, isStale: next == nil)
    }
}

// MARK: - Views

struct TideComplicationView: View {
    var entry: TideTimelineProvider.Entry

    var body: some View {
        switch entry.nextTide {
        case .some(let tide):
            nextTideContent(tide)
        case nil:
            staleContent
        }
    }

    private func nextTideContent(_ tide: WidgetTideEvent) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: tide.isHigh ? "arrow.up.to.line" : "arrow.down.to.line")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tide.isHigh ? Color(red: 0.95, green: 0.72, blue: 0.25) : .cyan)
                Text(WidgetTideFetch.timeString(tide.date))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
            }
        }
    }

    private var staleContent: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "water.waves.slash")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }
}

struct TideRectangularView: View {
    var entry: TideTimelineProvider.Entry

    var body: some View {
        if let tide = entry.nextTide {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: tide.isHigh ? "arrow.up.to.line" : "arrow.down.to.line")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(tide.isHigh ? Color(red: 0.95, green: 0.72, blue: 0.25) : .cyan)
                    Text("\(tide.label) tide · Amble")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Text(timerInterval: entry.date...tide.date, countsDown: true)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("at \(WidgetTideFetch.timeString(tide.date)) · \(String(format: "%.1f", tide.height)) m")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "water.waves.slash")
                    .foregroundStyle(.secondary)
                Text("Tides unavailable")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
    }
}

struct TideInlineView: View {
    var entry: TideTimelineProvider.Entry

    var body: some View {
        if let tide = entry.nextTide {
            Text("\(tide.isHigh ? "▲" : "▼") \(tide.label) \(WidgetTideFetch.timeString(tide.date))")
        } else {
            Text("Tides unavailable")
        }
    }
}

// MARK: - Widget

struct NextTideWidget: Widget {
    let kind: String = "PuffinCruisesWatchWidgets"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TideTimelineProvider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Next Tide")
        .description("Amble Harbour's next high or low water, live on your watch face and Smart Stack.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

struct WidgetEntryView: View {
    var entry: TideTimelineProvider.Entry

    var body: some View {
        Group {
            switch entry.nextTide {
            case .some(let tide):
                rectangularBody(tide)
            case nil:
                staleBody
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func rectangularBody(_ tide: WidgetTideEvent) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: tide.isHigh ? "arrow.up.to.line" : "arrow.down.to.line")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tide.isHigh ? Color(red: 0.95, green: 0.72, blue: 0.25) : .cyan)
                Text("\(tide.label.uppercased()) WATER")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Text(WidgetTideFetch.timeString(tide.date))
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("Amble Harbour · \(String(format: "%.1f", tide.height)) m")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var staleBody: some View {
        HStack(spacing: 5) {
            Image(systemName: "water.waves.slash")
                .foregroundStyle(.secondary)
            Text("Tides unavailable — open the app to refresh")
                .font(.system(size: 12, weight: .semibold))
        }
    }
}
