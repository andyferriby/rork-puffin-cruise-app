import SwiftUI
import WatchKit

nonisolated struct WatchSpecies: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let whereToSpot: String
}

/// Wildlife spotter — tick off species during your cruise, with a success
/// haptic on every sighting. Sightings persist between sessions.
struct WildlifePage: View {
    @AppStorage("spottedSpecies") private var spottedRaw = ""
    @State private var hapticPulse = false

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

    private var spotted: Set<String> {
        Set(spottedRaw.split(separator: ",").map(String.init))
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
    }

    private var progressCard: some View {
        HStack(spacing: 6) {
            Image(systemName: "binoculars.fill")
                .font(.system(size: 13))
                .foregroundStyle(WatchTheme.gold)
            Text("\(spotted.count) of \(species.count) spotted")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
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
        }
        spottedRaw = current.sorted().joined(separator: ",")
    }
}
