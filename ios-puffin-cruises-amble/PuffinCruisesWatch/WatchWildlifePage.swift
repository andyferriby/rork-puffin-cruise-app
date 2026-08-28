import SwiftUI
import WatchKit

nonisolated struct WatchSpecies: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let whereToSpot: String
}

nonisolated struct SpotterRank: Identifiable, Equatable {
    let threshold: Int
    let title: String
    let icon: String
    let colorKey: String

    var id: Int { threshold }
}

/// Wildlife spotter — tick off species during your cruise, earn spotter ranks
/// with a celebration haptic on every promotion. Sightings persist.
struct WildlifePage: View {
    @AppStorage("spottedSpecies") private var spottedRaw = ""
    @State private var hapticPulse = false
    @State private var celebratingRank: SpotterRank?

    private let species: [WatchSpecies] = [
        WatchSpecies(id: "puffin", name: "Atlantic Puffin", emoji: "🐧", whereToSpot: "All around Coquet Island"),
        WatchSpecies(id: "grey-seal", name: "Grey Seal", emoji: "🦭", whereToSpot: "Rocky ledges east of the island"),
        WatchSpecies(id: "arctic-tern", name: "Arctic Tern", emoji: "🕊️", whereToSpot: "Skimming the water nearby"),
        WatchSpecies(id: "roseate-tern", name: "Roseate Tern", emoji: "🪶", whereToSpot: "Nest boxes from the boat"),
        WatchSpecies(id: "common-eider", name: "Common Eider", emoji: "🦆", whereToSpot: "Close to shore in rafts"),
        WatchSpecies(id: "harbour-porpoise", name: "Harbour Porpoise", emoji: "🐬", whereToSpot: "Open water past the island"),
        WatchSpecies(id: "kittiwake", name: "Kittiwake", emoji: "🐦", whereToSpot: "Ledges and the boat's wake"),
        WatchSpecies(id: "shag", name: "European Shag", emoji: "🦤", whereToSpot: "Rocks, wings spread to dry")
    ]

    private let ranks: [SpotterRank] = [
        SpotterRank(threshold: 3, title: "Beachcomber", icon: "binoculars.fill", colorKey: "mint"),
        SpotterRank(threshold: 6, title: "Coquet Explorer", icon: "map.fill", colorKey: "gold"),
        SpotterRank(threshold: 8, title: "Puffin Legend", icon: "crown.fill", colorKey: "gold")
    ]

    private var spotted: Set<String> {
        Set(spottedRaw.split(separator: ",").map(String.init))
    }

    private var earnedRank: SpotterRank? {
        ranks.last { spotted.count >= $0.threshold }
    }

    private var nextRank: SpotterRank? {
        ranks.first { spotted.count < $0.threshold }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                WatchPageHeader(icon: "sparkles", title: "Spotter")
                progressCard
                ForEach(species) { animal in
                    speciesRow(animal)
                }
                if !spotted.isEmpty {
                    resetButton
                }
            }
            .padding(.horizontal, 4)
        }
        .background(WatchPageBackground())
        .overlay {
            if let rank = celebratingRank {
                celebrationOverlay(rank)
            }
        }
    }

    // MARK: - Progress & ranks

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "binoculars.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(WatchTheme.gold)
                Text("\(spotted.count) of \(species.count) spotted")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
            }

            if let rank = earnedRank {
                HStack(spacing: 5) {
                    Image(systemName: rank.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(WatchTheme.gold)
                    Text(rank.title)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(WatchTheme.gold)
                }
            }

            if let next = nextRank {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(next.threshold - spotted.count) more to \(next.title)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    ProgressView(value: Double(spotted.count) / Double(next.threshold))
                        .tint(WatchTheme.gold)
                }
            }
        }
        .watchCard()
        .opacity(hapticPulse ? 0.75 : 1)
        .animation(.easeInOut(duration: 0.15), value: hapticPulse)
    }

    private func speciesRow(_ animal: WatchSpecies) -> some View {
        let isSpotted = spotted.contains(animal.id)
        return Button {
            toggle(animal.id)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isSpotted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isSpotted ? WatchTheme.gold : .white.opacity(0.35))
                Text(animal.emoji)
                    .font(.system(size: 14))
                VStack(alignment: .leading, spacing: 1) {
                    Text(animal.name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .strikethrough(isSpotted, color: .white.opacity(0.4))
                    Text(animal.whereToSpot)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .opacity(isSpotted ? 0.65 : 1)
            .watchCard()
        }
        .buttonStyle(.plain)
    }

    private var resetButton: some View {
        Button {
            spottedRaw = ""
            WKInterfaceDevice.current().play(.stop)
        } label: {
            Label("Reset sightings", systemImage: "arrow.counterclockwise")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Celebration

    private func celebrationOverlay(_ rank: SpotterRank) -> some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                Text("🐧🦭🐬")
                    .font(.system(size: 22))
                Image(systemName: rank.icon)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(WatchTheme.gold)
                Text("RANK EARNED")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.6))
                Text(rank.title)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(WatchTheme.gold)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(WatchTheme.deep)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(WatchTheme.gold.opacity(0.6), lineWidth: 2)
                    }
            )
            .scaleEffect(celebratingRank == rank ? 1 : 0.4)
            .opacity(celebratingRank == rank ? 1 : 0)
        }
        .onTapGesture { dismissCelebration() }
        .task {
            try? await Task.sleep(for: .seconds(2.4))
            dismissCelebration()
        }
    }

    private func dismissCelebration() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            celebratingRank = nil
        }
    }

    // MARK: - Actions

    private func toggle(_ id: String) {
        var current = spotted
        if current.contains(id) {
            current.remove(id)
        } else {
            current.insert(id)
            WKInterfaceDevice.current().play(.success)
            hapticPulse = true
            Task {
                try? await Task.sleep(for: .seconds(0.3))
                hapticPulse = false
            }

            let previousRank = earnedRank
            let newCount = current.count
            if let promoted = ranks.first(where: { newCount >= $0.threshold }),
               previousRank == nil || promoted.threshold > (previousRank?.threshold ?? 0) {
                WKInterfaceDevice.current().play(.notification)
                celebratingRank = promoted
            }
        }
        spottedRaw = current.sorted().joined(separator: ",")
    }
}
