import Charts
import SwiftUI
import UserNotifications
import WidgetKit

@MainActor
@Observable
final class TideModel {
    private(set) var series: [TidePoint] = []
    private(set) var all: [TideEvent] = []
    private(set) var upcoming: [TideEvent] = []
    private(set) var isLoading = false
    private(set) var loadFailed = false

    var next: TideEvent? { upcoming.first { $0.date > Date() } }

    /// The most recent extreme that has already passed — used for tide momentum.
    var previous: TideEvent? { all.last { $0.date <= Date() } }

    /// Hourly sea level for the next 24 hours — drawn as the tide curve.
    var curve: [TidePoint] {
        let start = Date().addingTimeInterval(-3600)
        let end = Date().addingTimeInterval(24 * 3600)
        return series.filter { $0.date > start && $0.date < end }
    }

    var todaysTides: [TideEvent] {
        let calendar = Calendar.current
        return upcoming.filter { calendar.isDateInToday($0.date) }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        let points = await TideFetch.fetchSeries()
        loadFailed = points.isEmpty
        series = points
        let events = TideFetch.events(from: points)
        all = events
        upcoming = events.filter { $0.date > Date().addingTimeInterval(-600) }
        // Keep the complication and Smart Stack card in sync.
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Schedules local notifications 30 minutes before each upcoming tide.
enum TideAlerts {
    private static let idPrefix = "puffin-tide-"

    static func setEnabled(_ enabled: Bool, events: [TideEvent]) async {
        let center = UNUserNotificationCenter.current()
        await removeAll(center)
        guard enabled else { return }

        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }

        for event in events.prefix(4) {
            let fireIn = event.date.addingTimeInterval(-30 * 60).timeIntervalSinceNow
            guard fireIn > 0 else { continue }
            let content = UNMutableNotificationContent()
            content.title = "\(event.label) tide \(TideFetch.timeString(event.date))"
            content.body = event.isHigh
                ? "High water in 30 minutes — a lovely time for a harbour walk."
                : "Low water in 30 minutes — expect wide sands along the shore."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireIn, repeats: false)
            let request = UNNotificationRequest(
                identifier: idPrefix + String(event.date.timeIntervalSince1970),
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    static func removeAll(_ center: UNUserNotificationCenter) async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}

struct TidePage: View {
    @State private var model = TideModel()
    @AppStorage("tideAlertsEnabled") private var alertsEnabled = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                WatchPageHeader(icon: "water.waves", title: "Tides")
                if model.loadFailed {
                    WatchStatusCard(
                        icon: "wifi.exclamationmark",
                        title: "Couldn't load tides",
                        detail: "Pull down to retry."
                    )
                } else if let tide = model.next {
                    nextTideCard(tide)
                    momentumCard
                    tideCurveCard
                    todaysCard
                }
                alertsCard
            }
            .padding(.horizontal, 4)
        }
        .background(WatchPageBackground())
        .task {
            await model.load()
            if alertsEnabled {
                await TideAlerts.setEnabled(true, events: model.upcoming)
            }
        }
        .refreshable { await model.load() }
        .onChange(of: alertsEnabled) {
            Task { await TideAlerts.setEnabled(alertsEnabled, events: model.upcoming) }
        }
    }

    private func nextTideCard(_ tide: TideEvent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: tide.symbolName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tide.isHigh ? WatchTheme.gold : .cyan)
                Text("NEXT \(tide.label.uppercased()) TIDE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer(minLength: 0)
                // Next event is high water -> the tide is rising right now.
                HStack(spacing: 2) {
                    Image(systemName: tide.isHigh ? "arrow.up" : "arrow.down")
                        .font(.system(size: 10, weight: .black))
                        .symbolEffect(.bounce, options: .repeating)
                    Text(tide.isHigh ? "Rising" : "Falling")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(tide.isHigh ? WatchTheme.mint : .cyan)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill((tide.isHigh ? WatchTheme.mint : .cyan).opacity(0.16)))
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(TideFetch.timeString(tide.date))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(String(format: "%.1fm", tide.height))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.cyan)
            }
            Text(tide.date, style: .relative)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(WatchTheme.mint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .watchCard()
    }

    /// How far the water has travelled between the last extreme and the next one.
    private var momentum: (isRising: Bool, fraction: Double, minutesLeft: Int)? {
        guard let previous = model.previous, let next = model.next else { return nil }
        let span = next.date.timeIntervalSince(previous.date)
        guard span > 0 else { return nil }
        let elapsed = Date().timeIntervalSince(previous.date)
        let fraction = min(1, max(0, elapsed / span))
        return (next.isHigh, fraction, Int((span - elapsed) / 60))
    }

    @ViewBuilder
    private var momentumCard: some View {
        if let momentum {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: momentum.isRising ? "waveform.path.ecg" : "waveform")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(momentum.isRising ? WatchTheme.gold : .cyan)
                    Text("TIDE MOMENTUM")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer(minLength: 0)
                    Text(momentum.isRising ? "Rising" : "Ebbing")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(momentum.isRising ? WatchTheme.gold : .cyan)
                }

                ProgressView(value: momentum.fraction)
                    .tint(momentum.isRising ? WatchTheme.gold : .cyan)

                HStack {
                    Text("\(Int(momentum.fraction * 100))% to \(momentum.isRising ? "high" : "low") water")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer(minLength: 0)
                    Text("~\(max(0, momentum.minutesLeft)) min to go")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(WatchTheme.mint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .watchCard()
            .animation(.easeInOut(duration: 0.5), value: momentum.fraction)
        }
    }

    /// 24-hour sea-level curve with a gold "now" marker.
    private var tideCurveCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NEXT 24 HOURS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))

            Chart {
                ForEach(model.curve) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("Level", point.height)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(
                        colors: [.cyan, WatchTheme.gold],
                        startPoint: .init(x: 0.5, y: 0),
                        endPoint: .init(x: 0.5, y: 1)
                    ))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                }
                RuleMark(x: .value("Now", Date()))
                    .foregroundStyle(WatchTheme.gold.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 6)) {
                    AxisValueLabel(format: .dateTime.hour())
                        .font(.system(size: 8, weight: .semibold))
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 72)

            Text("Sea level at Amble Harbour")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .watchCard()
    }

    @ViewBuilder
    private var todaysCard: some View {
        if !model.todaysTides.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("TODAY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                ForEach(model.todaysTides) { tide in
                    HStack(spacing: 6) {
                        Image(systemName: tide.symbolName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(tide.isHigh ? WatchTheme.gold : .cyan)
                        Text(TideFetch.timeString(tide.date))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        Text(tide.label)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(String(format: "%.1fm", tide.height))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .watchCard()
        }
    }

    private var alertsCard: some View {
        HStack(spacing: 6) {
            Image(systemName: "bell.badge")
                .font(.system(size: 13))
                .foregroundStyle(WatchTheme.gold)
            VStack(alignment: .leading, spacing: 1) {
                Text("Tide alerts")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Ping 30 min before")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
            Toggle("", isOn: $alertsEnabled)
                .labelsHidden()
                .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .watchCard()
    }
}
