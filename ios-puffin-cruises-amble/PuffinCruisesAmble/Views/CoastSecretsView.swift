import SwiftUI
import UserNotifications

/// Coast Secrets — tide-aware "only in Amble" tips with live status, plus the
/// Golden Hour Club: tonight's best photo spot, rotating daily, with an alert
/// 40 minutes before sunset.
struct CoastSecretsView: View {
    @State private var tides: [TideEvent] = []
    @State private var sun: SunInfo?
    @State private var isLoading = true

    @AppStorage("coastSecretsLowWaterAlert") private var lowWaterAlertEnabled = false
    @AppStorage("coastSecretsGoldenHourAlert") private var goldenHourAlertEnabled = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    ProgressView("Reading the tide tables…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    goldenHourCard
                    ForEach(CoastSecretTip.all) { tip in
                        tipCard(tip)
                    }
                    lowWaterAlertCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Theme.bg)
        .navigationTitle("Coast Secrets")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        async let tideTask = AmbleConditions.fetchTides()
        async let sunTask = AmbleConditions.fetchSunset()
        tides = await tideTask
        sun = await sunTask
        isLoading = false
        await syncScheduledAlerts()
    }

    // MARK: - Golden Hour Club

    private var goldenHourCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "camera.filters")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.sandDeep)
                Text("GOLDEN HOUR CLUB")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(Theme.sandDeep)
                Spacer()
                alertToggle(isOn: Binding(
                    get: { goldenHourAlertEnabled },
                    set: { newValue in
                        goldenHourAlertEnabled = newValue
                        scheduleGoldenHourAlert(enabled: newValue)
                    }
                ))
            }

            if let sun {
                let spot = GoldenHourClub.todaysSpot()
                Text("Sunset tonight at \(AmbleConditions.timeString(sun.sunset)).")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("Tonight's best photo spot: \(spot).")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textMuted)
                Text("We'll ping you 40 minutes before the light turns — and the spot changes overnight, so there's always a new angle tomorrow.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textMuted)
                    .lineSpacing(3)
            } else {
                Text("Couldn't load tonight's sunset time. Pull down to retry.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .puffinCard(radius: 18, fill: Theme.sand.opacity(0.35))
    }

    // MARK: - Tips

    private func tipCard(_ tip: CoastSecretTip) -> some View {
        let status = tip.status(now: Date(), tides: tides)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: tip.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.sea)
                Text(tip.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(status.badge)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(status.isOpen ? Color(hex: 0x1B7A43) : Theme.textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((status.isOpen ? Color(hex: 0x1B7A43) : Theme.textMuted).opacity(0.12))
                    .clipShape(.capsule)
            }
            Text(tip.detail)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textMuted)
                .lineSpacing(3)
            if let time = status.timeText {
                Text(status.isOpen ? "Perfect now — until \(time)" : "Best from \(time)")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(status.isOpen ? Color(hex: 0x1B7A43) : Theme.sea)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .puffinCard(radius: 18, fill: .white)
    }

    // MARK: - Low water alert

    private var lowWaterAlertCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "water.waves")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.sea)
            VStack(alignment: .leading, spacing: 2) {
                Text("Low water alert")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("Ping me the moment the shore opens at the next low tide.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer()
            alertToggle(isOn: Binding(
                get: { lowWaterAlertEnabled },
                set: { newValue in
                    lowWaterAlertEnabled = newValue
                    scheduleLowWaterAlert(enabled: newValue)
                }
            ))
        }
        .padding(16)
        .puffinCard(radius: 18, fill: Theme.foam)
    }

    private func alertToggle(isOn: Binding<Bool>) -> some View {
        Toggle("", isOn: isOn)
            .labelsHidden()
            .tint(Theme.sea)
    }

    // MARK: - Notifications

    /// (Re)schedules local alerts to match the toggles once tide/sunset data is in.
    private func syncScheduledAlerts() async {
        if goldenHourAlertEnabled { scheduleGoldenHourAlert(enabled: true) }
        if lowWaterAlertEnabled { scheduleLowWaterAlert(enabled: true) }
    }

    private func scheduleGoldenHourAlert(enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [GoldenHourClub.notificationID])
        guard enabled, let sun else { return }
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let fireDate = sun.sunset.addingTimeInterval(-40 * 60)
            let interval = fireDate.timeIntervalSinceNow
            guard interval > 60 else { return }
            let content = UNMutableNotificationContent()
            content.title = "Golden hour soon"
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_GB")
            formatter.timeZone = TimeZone(identifier: "Europe/London")
            formatter.dateFormat = "h:mm a"
            content.body = "Sunset at \(formatter.string(from: sun.sunset)). Tonight's best photo spot: \(GoldenHourClub.todaysSpot())."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            center.add(UNNotificationRequest(identifier: GoldenHourClub.notificationID, content: content, trigger: trigger))
        }
    }

    private func scheduleLowWaterAlert(enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [CoastSecretTip.lowWaterNotificationID])
        guard enabled else { return }
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            // The moment the shore opens: 3 hours before the next low water.
            guard let low = self.tides.first(where: { !$0.isHigh && $0.date > Date() })?.date else { return }
            let fireDate = low.addingTimeInterval(-3 * 3600)
            let interval = fireDate.timeIntervalSinceNow
            guard interval > 60 else { return }
            let content = UNMutableNotificationContent()
            content.title = "The shore is opening"
            content.body = "Low water at \(AmbleConditions.shortTimeString(low)) — rock pools and sands are ready. Get down early."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            center.add(UNNotificationRequest(identifier: CoastSecretTip.lowWaterNotificationID, content: content, trigger: trigger))
        }
    }
}

// MARK: - Golden Hour Club

enum GoldenHourClub {
    static let notificationID = "puffin-golden-hour"

    /// Scenic spots the daily photo pick rotates through.
    private static let spots = [
        "Amble Pier",
        "Little Shore",
        "The harbour mouth",
        "Warkworth beach dunes",
        "The Coquet Island viewpoint"
    ]

    /// Stable for the whole day, changes overnight.
    static func todaysSpot(now: Date = Date()) -> String {
        spots[AmbleConditions.dayNumber(now) % spots.count]
    }
}

// MARK: - Coast secret tips

struct CoastSecretTip: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    /// Hours before low water when the spot becomes usable, and hours after
    /// low water before the sea closes it again.
    let hoursBeforeLow: Double
    let hoursAfterLow: Double

    static let lowWaterNotificationID = "puffin-low-water"

    static let all: [CoastSecretTip] = [
        CoastSecretTip(
            id: "rockpools",
            title: "Rock pools of Little Shore",
            detail: "At low water, the rocks south of the harbour fill with pools — crabs, anemones and shimmering blennies. Best with wellies.",
            icon: "drop.circle",
            hoursBeforeLow: 3,
            hoursAfterLow: 1.5
        ),
        CoastSecretTip(
            id: "sands",
            title: "The wide sands to Warkworth",
            detail: "When the tide drops, the beach opens into vast flat sands — you can walk the whole bay towards Warkworth Castle.",
            icon: "figure.walk",
            hoursBeforeLow: 2.5,
            hoursAfterLow: 2
        ),
        CoastSecretTip(
            id: "oldpier",
            title: "Old pier remains",
            detail: "Out on the flats you can still spot the timber bones of Amble's older harbour works — best seen when the water is out.",
            icon: "hammer",
            hoursBeforeLow: 2,
            hoursAfterLow: 1
        ),
        CoastSecretTip(
            id: "curlews",
            title: "Curlews on the flats",
            detail: "Exposed mudflats pull in curlews, oystercatchers and redshank — bring binoculars as the tide falls.",
            icon: "bird",
            hoursBeforeLow: 3,
            hoursAfterLow: 2
        )
    ]

    struct Status {
        let isOpen: Bool
        let badge: String
        let timeText: String?
    }

    static func nextLowWater(after date: Date, tides: [TideEvent]) -> Date? {
        tides.first { !$0.isHigh && $0.date >= date.addingTimeInterval(-3600) }?.date
    }

    func status(now: Date, tides: [TideEvent]) -> Status {
        let lows = tides.filter { !$0.isHigh }
        for low in lows {
            let start = low.date.addingTimeInterval(-hoursBeforeLow * 3600)
            let end = low.date.addingTimeInterval(hoursAfterLow * 3600)
            if now >= start && now <= end {
                return Status(isOpen: true, badge: "PERFECT NOW", timeText: AmbleConditions.shortTimeString(end))
            }
        }
        if let upcoming = lows.first(where: { $0.date.addingTimeInterval(-hoursBeforeLow * 3600) > now }) {
            let start = upcoming.date.addingTimeInterval(-hoursBeforeLow * 3600)
            return Status(isOpen: false, badge: "TIDE-WAITING", timeText: AmbleConditions.shortTimeString(start))
        }
        return Status(isOpen: false, badge: "TIDE-WAITING", timeText: nil)
    }
}
