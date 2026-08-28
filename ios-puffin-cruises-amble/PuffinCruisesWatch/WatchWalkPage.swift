import SwiftUI
import WatchKit

nonisolated struct WalkStop: Identifiable, Hashable {
    let name: String
    let emoji: String
    let detail: String
    let minutesFromPrevious: Int
    let latitude: Double
    let longitude: Double

    var id: String { name }
}

@MainActor
@Observable
final class WalkModel {
    private(set) var currentIndex: Int?
    private(set) var hasFinished = false

    var isWalking: Bool { currentIndex != nil }

    func start() {
        currentIndex = 0
        hasFinished = false
        WKInterfaceDevice.current().play(.start)
    }

    func advance() {
        guard let index = currentIndex, index < WalkContent.stops.count - 1 else { return }
        currentIndex = index + 1
        WKInterfaceDevice.current().play(.notification)
    }

    func finish() {
        currentIndex = nil
        hasFinished = true
        WKInterfaceDevice.current().play(.success)
    }

    func dismissSummary() {
        hasFinished = false
    }

    func endWalk() {
        currentIndex = nil
        WKInterfaceDevice.current().play(.stop)
    }
}

/// Content for the guided Amble harbour walk.
enum WalkContent {
    static let stops: [WalkStop] = [
        WalkStop(
            name: "Booking Office",
            emoji: "🎟️",
            detail: "Start at Dave Gray's booking office on Harbour Road. Collect tickets and say hello to the crew.",
            minutesFromPrevious: 0,
            latitude: 55.3336,
            longitude: -1.5812
        ),
        WalkStop(
            name: "Boarding Pier",
            emoji: "⚓",
            detail: "The crew scan QR tickets here. Watch the boat come alongside and grab a classic harbour photo.",
            minutesFromPrevious: 2,
            latitude: 55.3338,
            longitude: -1.5803
        ),
        WalkStop(
            name: "Harbour Village",
            emoji: "🛍️",
            detail: "Colourful cabins with independent shops, gifts and coffee — perfect before or after your cruise.",
            minutesFromPrevious: 3,
            latitude: 55.3334,
            longitude: -1.5818
        ),
        WalkStop(
            name: "The Old Boathouse",
            emoji: "🦞",
            detail: "Award-winning seafood right on the harbour front. Book ahead — tables go quickly on sunny days.",
            minutesFromPrevious: 2,
            latitude: 55.3331,
            longitude: -1.5828
        ),
        WalkStop(
            name: "North Pier Lighthouse",
            emoji: "🗼",
            detail: "Stroll out along the pier to the little lighthouse for views back over Amble and its working harbour.",
            minutesFromPrevious: 5,
            latitude: 55.3346,
            longitude: -1.5851
        ),
        WalkStop(
            name: "Coquet Viewpoint",
            emoji: "🐧",
            detail: "Look east across the water to Coquet Island — puffins, seals and terns in season. Finish with the sunset behind you.",
            minutesFromPrevious: 8,
            latitude: 55.3354,
            longitude: -1.5735
        )
    ]

    static let bookingOfficePhone = "07752861914"

    static var totalMinutes: Int {
        stops.reduce(0) { $0 + $1.minutesFromPrevious }
    }
}

struct WalkPage: View {
    @State private var model = WalkModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                WatchPageHeader(icon: "figure.walk", title: "Harbour Walk")
                if model.hasFinished {
                    summaryCard
                } else if model.isWalking {
                    guidedCard
                } else {
                    overviewCard
                    stopsList
                }
            }
            .padding(.horizontal, 4)
        }
        .background(WatchPageBackground())
    }

    // MARK: - Overview

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("A gentle 30-minute stroll through Amble's working harbour — six stops, haptic pings at each turn.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundStyle(WatchTheme.gold)
                Text("~\(WalkContent.totalMinutes) min")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.system(size: 10))
                    .foregroundStyle(WatchTheme.gold)
                Text("\(WalkContent.stops.count) stops")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .watchCard()

        // Start button lives directly under the overview card.
    }

    private var stopsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                model.start()
            } label: {
                Label("Start guided walk", systemImage: "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
            }
            .tint(WatchTheme.gold)

            ForEach(Array(WalkContent.stops.enumerated()), id: \.element.id) { index, stop in
                HStack(spacing: 6) {
                    Text(stop.emoji)
                        .font(.system(size: 14))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(stop.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                        Text(stopMinutesLabel(index))
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer(minLength: 0)
                    Button {
                        openDirections(to: stop)
                    } label: {
                        Image(systemName: "arrow.triangle.turn.up.right.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(.cyan)
                    }
                    .buttonStyle(.plain)
                }
                .watchCard()
            }
        }
    }

    // MARK: - Guided mode

    @ViewBuilder
    private var guidedCard: some View {
        if let index = model.currentIndex, index < WalkContent.stops.count {
            let stop = WalkContent.stops[index]
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text("STOP \(index + 1) OF \(WalkContent.stops.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(WatchTheme.gold)
                    Spacer(minLength: 0)
                    Text("~\(stop.minutesFromPrevious) min")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Text(stop.emoji)
                    .font(.system(size: 30))
                Text(stop.name)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                Text(stop.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)

                progressDots(index)

                Button {
                    if index == WalkContent.stops.count - 1 {
                        model.finish()
                    } else {
                        model.advance()
                    }
                } label: {
                    Label(
                        index == WalkContent.stops.count - 1 ? "Finish walk" : "Next stop",
                        systemImage: index == WalkContent.stops.count - 1 ? "flag.checkered" : "arrow.right"
                    )
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                }
                .tint(WatchTheme.gold)

                HStack(spacing: 6) {
                    Button {
                        openDirections(to: stop)
                    } label: {
                        Label("Directions", systemImage: "arrow.triangle.turn.up.right.circle")
                            .font(.system(size: 11, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.cyan)

                    Button {
                        model.endWalk()
                    } label: {
                        Label("End", systemImage: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.white.opacity(0.25))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .watchCard()

            Button {
                callBookingOffice()
            } label: {
                Label("Call booking office", systemImage: "phone.fill")
                    .font(.system(size: 12, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .tint(.green)
        }
    }

    private func progressDots(_ currentIndex: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(WalkContent.stops.enumerated()), id: \.element.id) { index, _ in
                Capsule()
                    .fill(index <= currentIndex ? WatchTheme.gold : Color.white.opacity(0.2))
                    .frame(width: index == currentIndex ? 14 : 8, height: 4)
                    .animation(.easeInOut(duration: 0.2), value: model.currentIndex)
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 24))
                .foregroundStyle(WatchTheme.gold)
            Text("Walk complete!")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.white)
            Text("You explored Amble harbour from the booking office to the Coquet viewpoint. Fancy a cruise to see it from the water?")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            Button {
                model.dismissSummary()
            } label: {
                Label("Back to stops", systemImage: "list.bullet")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
            }
            .tint(WatchTheme.gold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .watchCard()
    }

    // MARK: - Helpers

    private func stopMinutesLabel(_ index: Int) -> String {
        let minutes = WalkContent.stops[index].minutesFromPrevious
        return minutes == 0 ? "Start here" : "~\(minutes) min from previous"
    }

    private func openDirections(to stop: WalkStop) {
        guard let url = URL(string: "maps://?daddr=\(stop.latitude),\(stop.longitude)&dirflg=w") else { return }
        WKExtension.shared().openSystemURL(url)
    }

    private func callBookingOffice() {
        guard let url = URL(string: "tel:\(WalkContent.bookingOfficePhone)") else { return }
        WKExtension.shared().openSystemURL(url)
    }
}
