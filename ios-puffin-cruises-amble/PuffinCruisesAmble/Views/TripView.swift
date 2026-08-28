import SwiftUI

private struct Sighting: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let hint: String
    let points: Int
}

private struct TrailStop: Identifiable {
    let id: String
    let title: String
    let clue: String
    let icon: String
}

struct TripView: View {
    @State private var seenIds: Set<String> = ["puffin"]
    @State private var trailIds: Set<String> = ["harbour"]

    private let sightings: [Sighting] = [
        Sighting(id: "puffin", name: "Puffin", emoji: "🐧", hint: "Look for colourful beaks near the burrows", points: 20),
        Sighting(id: "seal", name: "Grey seal", emoji: "🦭", hint: "Watch the rocks on the island edge", points: 15),
        Sighting(id: "tern", name: "Tern", emoji: "🕊️", hint: "Fast white birds diving for fish", points: 10),
        Sighting(id: "eider", name: "Eider duck", emoji: "🦆", hint: "Listen for the soft cooing call", points: 10),
        Sighting(id: "porpoise", name: "Porpoise", emoji: "🐬", hint: "A quick dark fin in open water", points: 30)
    ]

    private let trailStops: [TrailStop] = [
        TrailStop(id: "harbour", title: "Harbour lookout", clue: "Count three working boats before departure.", icon: "steeringwheel"),
        TrailStop(id: "waves", title: "Wave watcher", clue: "Spot the tallest splash as the boat turns seaward.", icon: "water.waves"),
        TrailStop(id: "island", title: "Island ranger", clue: "Find the lighthouse and point it out to your grown-up.", icon: "safari.fill"),
        TrailStop(id: "safe", title: "Safety skipper", clue: "Show where your lifejacket would be in an emergency.", icon: "lifepreserver.fill")
    ]

    private var totalPoints: Int {
        sightings.reduce(0) { $0 + (seenIds.contains($1.id) ? $1.points : 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero

                VStack(spacing: 12) {
                    weatherCard
                    memoryCard
                }
                .padding(16)

                sectionHeader("Wildlife sighting log", trailing: "\(totalPoints) pts")
                VStack(spacing: 10) {
                    ForEach(sightings) { item in
                        sightingCard(item)
                    }
                }
                .padding(.horizontal, 16)

                sectionHeader("Kids activity trail", trailing: "\(trailIds.count)/\(trailStops.count)")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(trailStops) { stop in
                        trailCard(stop)
                    }
                }
                .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    Image(systemName: "leaf.fill").font(.system(size: 20)).foregroundStyle(Theme.puffin)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Junior Island Ranger")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(Theme.deep)
                        Text("Complete the trail and spot 3 animals to unlock a souvenir badge screen.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.sea)
                            .lineSpacing(3)
                    }
                    Image(systemName: "star.fill").font(.system(size: 18)).foregroundStyle(Theme.sandDeep)
                }
                .padding(16)
                .background(Theme.sand)
                .clipShape(.rect(cornerRadius: 22))
                .padding(16)
            }
            .padding(.bottom, 38)
        }
        .background(Theme.bg)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Theme.ink, Theme.deep, Color(hex: 0x0E6A83)], startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(Theme.sand.opacity(0.18))
                .frame(width: 150, height: 150)
                .offset(x: 170, y: -30)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "sparkles").font(.system(size: 12))
                    Text("Live trip mode").font(.system(size: 12, weight: .black))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(.white.opacity(0.13))
                .clipShape(.capsule)
                .padding(.bottom, 15)

                Text("Today's Puffin Adventure")
                    .font(.system(size: 35, weight: .black))
                    .foregroundStyle(.white)

                Text("Boarding, sea outlook, wildlife spotting, kids trail and memory card in one place.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineSpacing(4)
                    .padding(.top, 9)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NEXT CHECK-IN")
                            .font(.system(size: 11, weight: .black))
                            .tracking(1)
                            .foregroundStyle(Theme.sand)
                        Text("Amble Harbour · 12:40")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text("LIVE")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.coral)
                        .clipShape(.capsule)
                }
                .padding(15)
                .background(.white.opacity(0.13))
                .clipShape(.rect(cornerRadius: 20))
                .overlay { RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.18), lineWidth: 1) }
                .padding(.top, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 70)
            .padding(.bottom, 26)
        }
        .clipped()
    }

    private var weatherCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.puffin)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weather & sea conditions")
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(Theme.text)
                    Text("Updated by crew before sailing")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textMuted)
                }
            }

            HStack(spacing: 8) {
                metric("Sea", "Moderate")
                metric("Wind", "NE 9 mph")
                metric("Temp", "15°C")
            }
            .padding(.top, 15)

            Text("Bring a light jacket — it feels cooler around Coquet Island. Sailing expected to run as planned.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.text)
                .lineSpacing(3)
                .padding(.top, 13)
        }
        .padding(16)
        .background(LinearGradient(colors: [Color(hex: 0xEAF7FF), Color(hex: 0xFFF5DF)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(.rect(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(Theme.border, lineWidth: 1) }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.textMuted)
            Text(value).font(.system(size: 14, weight: .black)).foregroundStyle(Theme.deep)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(.white.opacity(0.7))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var memoryCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.system(size: 20))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Theme.sea)
                .clipShape(.rect(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 3) {
                Text("Photo memories")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Theme.text)
                Text("After your trip, your best snaps and spotted wildlife become a shareable cruise memory card.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textMuted)
                    .lineSpacing(3)
            }
        }
        .padding(16)
        .puffinCard(radius: 22, fill: .white)
    }

    private func sectionHeader(_ title: String, trailing: String) -> some View {
        HStack {
            Text(title).font(.system(size: 22, weight: .black)).foregroundStyle(Theme.text)
            Spacer()
            Text(trailing).font(.system(size: 15, weight: .black)).foregroundStyle(Theme.puffin)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private func sightingCard(_ item: Sighting) -> some View {
        let active = seenIds.contains(item.id)
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if active { seenIds.remove(item.id) } else { seenIds.insert(item.id) }
            }
        } label: {
            HStack(spacing: 12) {
                Text(item.emoji).font(.system(size: 32))
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name).font(.system(size: 16, weight: .black)).foregroundStyle(Theme.text)
                    Text(item.hint).font(.system(size: 12)).foregroundStyle(Theme.textMuted)
                }
                Spacer()
                ZStack {
                    Circle().fill(active ? Theme.puffin : Theme.foam).frame(width: 30, height: 30)
                    Image(systemName: active ? "checkmark" : "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(active ? .white : Theme.sea)
                }
            }
            .padding(13)
            .background(active ? Color(hex: 0xFFF8EE) : .white)
            .clipShape(.rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(active ? Theme.puffin.opacity(0.45) : Theme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func trailCard(_ stop: TrailStop) -> some View {
        let done = trailIds.contains(stop.id)
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                if done { trailIds.remove(stop.id) } else { trailIds.insert(stop.id) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: stop.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(done ? .white : Theme.sea)
                Text(stop.title)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(done ? .white : Theme.text)
                Text(stop.clue)
                    .font(.system(size: 12))
                    .foregroundStyle(done ? .white.opacity(0.82) : Theme.textMuted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
            .padding(14)
            .background(done ? Theme.sea : .white)
            .clipShape(.rect(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22).stroke(done ? Theme.sea : Theme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
