import SwiftUI

nonisolated struct Species: Identifiable, Hashable {
    let id: String
    let name: String
    let latinName: String
    let emoji: String
    let description: String
    let funFacts: [String]
    let bestSeason: String
    let whereToSpot: String
    let category: String
}

struct WildlifeView: View {
    @State private var expandedId: String?
    @State private var category = "All"

    private let categories = ["All", "Birds", "Marine Life", "Coastal Life"]

    private let species: [Species] = [
        Species(
            id: "puffin",
            name: "Atlantic Puffin",
            latinName: "Fratercula arctica",
            emoji: "🐧",
            description: "The star of Coquet Island. Around 45,000 puffins nest here each summer, making it one of the UK's most important puffin colonies. Watch them dive for sand eels, waddle across the cliffs, and return to their burrows with beaks full of fish.",
            funFacts: [
                "Puffins can dive up to 60 metres deep.",
                "They mate for life and return to the same burrow each year.",
                "A baby puffin is called a 'puffling'.",
                "Their colourful beaks fade to grey in winter and brighten for breeding season."
            ],
            bestSeason: "April – July (peak June)",
            whereToSpot: "All around Coquet Island; best viewed from the upper deck.",
            category: "Birds"
        ),
        Species(
            id: "grey-seal",
            name: "Grey Seal",
            latinName: "Halichoerus grypus",
            emoji: "🦭",
            description: "Coquet Island's rocky shores are home to a thriving grey seal colony. These curious, intelligent mammals can often be seen lounging on the rocks or popping their heads above water to watch the boat go by. Pups are born with white coats in autumn.",
            funFacts: [
                "Grey seals can hold their breath for up to 20 minutes.",
                "The UK has around 40% of the world's grey seal population.",
                "Pups triple their birth weight in just 3 weeks on rich milk.",
                "They can recognise individual boat engines and voices."
            ],
            bestSeason: "Year-round; pups born September – November",
            whereToSpot: "Rocky ledges on the eastern side of Coquet Island.",
            category: "Marine Life"
        ),
        Species(
            id: "arctic-tern",
            name: "Arctic Tern",
            latinName: "Sterna paradisaea",
            emoji: "🕊️",
            description: "The ultimate long-distance traveller. Arctic terns migrate from Antarctica to Coquet Island each spring — a round trip of over 70,000 km. Watch these elegant, fork-tailed birds hover and plunge-dive for small fish in the waters around the island.",
            funFacts: [
                "Arctic terns see more daylight than any other creature.",
                "They can live over 30 years.",
                "One tracked tern flew 96,000 km in a single year.",
                "They aggressively defend their nests — watch from a safe distance!"
            ],
            bestSeason: "May – August",
            whereToSpot: "Skimming the water near the island's northern shore.",
            category: "Birds"
        ),
        Species(
            id: "roseate-tern",
            name: "Roseate Tern",
            latinName: "Sterna dougallii",
            emoji: "🪶",
            description: "Coquet Island hosts the UK's largest colony of roseate terns — one of Britain's rarest breeding seabirds. Their delicate pinkish breast feathers and graceful flight make them a photographer's dream. The RSPB wardens protect them around the clock.",
            funFacts: [
                "Coquet Island holds over 90% of the UK's breeding roseate terns.",
                "They nest in specially built boxes to protect them from gulls.",
                "Their name comes from the rosy flush on their breast plumage.",
                "They are strictly protected — landing on Coquet Island is prohibited."
            ],
            bestSeason: "May – July",
            whereToSpot: "Nest boxes visible from the boat; look for the pink-tinged breast.",
            category: "Birds"
        ),
        Species(
            id: "common-eider",
            name: "Common Eider",
            latinName: "Somateria mollissima",
            emoji: "🦆",
            description: "The UK's heaviest and fastest-flying duck. Eiders are famous for their soft down feathers, which the females pluck from their own breast to line their nests. Listen for their gentle, cooing 'ah-ooo' call drifting across the water.",
            funFacts: [
                "Eiderdown has been harvested sustainably in Northumberland for centuries.",
                "Females fast for the entire 26-day incubation period.",
                "Ducklings form crèches watched over by several females.",
                "They can fly at speeds up to 70 mph."
            ],
            bestSeason: "Year-round; ducklings May – June",
            whereToSpot: "Close to shore around the island; often in large rafts.",
            category: "Birds"
        ),
        Species(
            id: "harbour-porpoise",
            name: "Harbour Porpoise",
            latinName: "Phocoena phocoena",
            emoji: "🐬",
            description: "The smallest cetacean in UK waters and a lucky sighting on any cruise. Look for a small, dark triangular fin breaking the surface in calm conditions. They are shy and rarely leap, so keep your eyes on the open water beyond the island.",
            funFacts: [
                "Harbour porpoises need to eat around 10% of their body weight daily.",
                "They use echolocation clicks far above human hearing.",
                "Unlike dolphins, they rarely ride bow waves.",
                "Calm, flat seas give the best chance of a sighting."
            ],
            bestSeason: "Year-round; best in calm summer seas",
            whereToSpot: "Open water between Amble and Coquet Island.",
            category: "Marine Life"
        ),
        Species(
            id: "kittiwake",
            name: "Kittiwake",
            latinName: "Rissa tridactyla",
            emoji: "🐦",
            description: "A gentle, ocean-going gull named after its distinctive 'kitti-wake' call. They nest on narrow cliff ledges and spend most of the year far out at sea, returning to the Northumberland coast only to breed.",
            funFacts: [
                "They spend the winter far out in the Atlantic Ocean.",
                "Kittiwakes have black legs, unlike most other gulls.",
                "Chicks stay still on tiny ledges to avoid falling.",
                "Their numbers are declining, making each sighting special."
            ],
            bestSeason: "March – August",
            whereToSpot: "Cliff ledges and following the boat's wake.",
            category: "Coastal Life"
        ),
        Species(
            id: "shag",
            name: "European Shag",
            latinName: "Gulosus aristotelis",
            emoji: "🖤",
            description: "A sleek, dark seabird with an emerald sheen and a distinctive crest in breeding season. Shags are superb divers, disappearing beneath the surface for up to a minute in search of sand eels among the rocks.",
            funFacts: [
                "Their feathers are not fully waterproof, so they dry with wings spread.",
                "Shags can dive to depths of 45 metres.",
                "The breeding crest appears only early in the season.",
                "They are smaller and slimmer than cormorants."
            ],
            bestSeason: "Year-round",
            whereToSpot: "Perched on rocks with wings outstretched to dry.",
            category: "Coastal Life"
        )
    ]

    private var filtered: [Species] {
        category == "All" ? species : species.filter { $0.category == category }
    }

    private func color(for category: String) -> Color {
        switch category {
        case "Birds": return Theme.sea
        case "Marine Life": return Theme.wave
        default: return Color(hex: 0x3A8C6E)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [Theme.deep, Theme.sea], startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 7) {
                            Image(systemName: "sparkles").font(.system(size: 12))
                            Text("Field guide").font(.system(size: 12, weight: .black))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.15))
                        .clipShape(.capsule)

                        Text("Wildlife of\nCoquet Island")
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(.white)
                        Text("Tap any species to learn what to look for on your cruise.")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineSpacing(4)
                    }
                    .padding(20)
                    .padding(.top, 40)
                }
                .clipped()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { item in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { category = item }
                            } label: {
                                Text(item)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(category == item ? .white : Theme.sea)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(category == item ? Theme.sea : .white)
                                    .clipShape(.capsule)
                                    .overlay { Capsule().stroke(Theme.border, lineWidth: 1) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 16)
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)

                VStack(spacing: 12) {
                    ForEach(filtered) { item in
                        speciesCard(item)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 36)
        }
        .background(Theme.bg)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func speciesCard(_ item: Species) -> some View {
        let expanded = expandedId == item.id
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    expandedId = expanded ? nil : item.id
                }
            } label: {
                HStack(spacing: 14) {
                    Text(item.emoji)
                        .font(.system(size: 32))
                        .frame(width: 60, height: 60)
                        .background(color(for: item.category).opacity(0.12))
                        .clipShape(.rect(cornerRadius: 18))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(Theme.text)
                        Text(item.latinName)
                            .font(.system(size: 12).italic())
                            .foregroundStyle(Theme.textMuted)
                        Text(item.category)
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(color(for: item.category))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(color(for: item.category).opacity(0.12))
                            .clipShape(.capsule)
                            .padding(.top, 2)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textMuted)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .padding(14)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 14) {
                    Text(item.description)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.text)
                        .lineSpacing(4)

                    VStack(alignment: .leading, spacing: 8) {
                        infoRow(icon: "calendar", label: "Best season", value: item.bestSeason)
                        infoRow(icon: "mappin.and.ellipse", label: "Where to spot", value: item.whereToSpot)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("FUN FACTS")
                            .font(.system(size: 11, weight: .black))
                            .tracking(1)
                            .foregroundStyle(Theme.textMuted)
                        ForEach(item.funFacts, id: \.self) { fact in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•").foregroundStyle(color(for: item.category)).font(.system(size: 15, weight: .black))
                                Text(fact)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.text)
                                    .lineSpacing(3)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.foam)
                    .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .puffinCard(radius: 20, fill: .white)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Theme.sea)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 11, weight: .black)).foregroundStyle(Theme.textMuted)
                Text(value).font(.system(size: 13)).foregroundStyle(Theme.text).lineSpacing(2)
            }
        }
    }
}
