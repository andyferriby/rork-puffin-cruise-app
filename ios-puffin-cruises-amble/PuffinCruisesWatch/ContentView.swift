import SwiftUI

struct ContentView: View {
    @State private var model = WatchScheduleModel()

    var body: some View {
        NavigationStack {
            ZStack {
                WatchPageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        nextSailingCard
                        todaysSailingsCard
                        exploreLinks
                    }
                    .padding(.horizontal, 4)
                }
            }
            .navigationTitle("Puffin Cruises")
            .task { await model.load() }
            .refreshable { await model.load() }
        }
    }

    // MARK: - Next sailing

    @ViewBuilder
    private var nextSailingCard: some View {
        if model.loadFailed {
            WatchStatusCard(
                icon: "wifi.exclamationmark",
                title: "Couldn't load sailings",
                detail: "Pull down to retry."
            )
        } else if let sailing = model.nextSailing, let date = model.nextSailingDate {
            VStack(alignment: .leading, spacing: 4) {
                Text("NEXT SAILING")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(WatchTheme.gold)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(sailing.time)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(sailing.cruiseEmoji)
                        .font(.system(size: 18))
                }

                Text(sailing.cruiseName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)

                Text(timerInterval: Date()...date, countsDown: true)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(WatchTheme.mint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .watchCard()
        } else if !model.isLoading {
            WatchStatusCard(
                icon: "moon.zzz",
                title: "No more sailings today",
                detail: "See you tomorrow!"
            )
        }
    }

    // MARK: - Today's list

    @ViewBuilder
    private var todaysSailingsCard: some View {
        if !model.todaysSailings.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("TODAY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))

                ForEach(model.todaysSailings) { sailing in
                    HStack(alignment: .center, spacing: 6) {
                        Text(sailing.cruiseEmoji)
                            .font(.system(size: 13))
                        Text(sailing.time)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        Text(sailing.cruiseName)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .watchCard()
        }
    }

    // MARK: - Explore links

    private var exploreLinks: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EXPLORE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))

            pageLink(destination: TidePage(), icon: "water.waves", label: "Live Tides", tint: WatchTheme.mint)
            pageLink(destination: BoatPage(), icon: "location.fill", label: "Boat Tracker", tint: WatchTheme.gold)
            pageLink(destination: WalkPage(), icon: "figure.walk", label: "Harbour Walk", tint: WatchTheme.mint)
            pageLink(destination: WildlifePage(), icon: "sparkles", label: "Wildlife Spotter", tint: WatchTheme.gold)
        }
    }

    private func pageLink(destination: some View, icon: String, label: String, tint: Color) -> some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .watchCard()
        }
        .buttonStyle(.plain)
    }
}
