import SwiftUI

// MARK: - Wildlife Model

struct WildlifeSpecies: Identifiable {
    let id: String
    let name: String
    let latinName: String
    let emoji: String
    let description: String
    let funFacts: [String]
    let bestSeason: String
    let whereToSpot: String
    let category: WildlifeCategory
}

enum WildlifeCategory: String, CaseIterable {
    case birds = "Birds"
    case marine = "Marine Life"
    case coastal = "Coastal Life"

    var icon: String {
        switch self {
        case .birds: return "bird.fill"
        case .marine: return "fish.fill"
        case .coastal: return "leaf.fill"
        }
    }

    var color: Color {
        switch self {
        case .birds: return Theme.sea
        case .marine: return Theme.wave
        case .coastal: return Color(hex: "3A8C6E")
        }
    }
}

private let species: [WildlifeSpecies] = [
    WildlifeSpecies(
        id: "puffin",
        name: "Atlantic Puffin",
        latinName: "Fratercula arctica",
        emoji: "🐧",
        description: "The star of Coquet Island. Around 45,000 puffins nest here each summer, making it one of the UK's most important puffin colonies. Watch them dive for sand eels, waddle across the cliffs, and return to their burrows with beaks full of fish.",
        funFacts: [
            "Puffins can dive up to 60 metres deep.",
            "They mate for life and return to the same burrow each year.",
            "A baby puffin is called a 'puffling'.",
            "Their colourful beaks fade to grey in winter and brighten for breeding season.",
        ],
        bestSeason: "April – July (peak June)",
        whereToSpot: "All around Coquet Island; best viewed from the boat's upper deck.",
        category: .birds
    ),
    WildlifeSpecies(
        id: "grey-seal",
        name: "Grey Seal",
        latinName: "Halichoerus grypus",
        emoji: "🦭",
        description: "Coquet Island's rocky shores are home to a thriving grey seal colony. These curious, intelligent mammals can often be seen lounging on the rocks or popping their heads above water to watch the boat go by. Pups are born with white coats in autumn.",
        funFacts: [
            "Grey seals can hold their breath for up to 20 minutes.",
            "The UK has around 40% of the world's grey seal population.",
            "Pups triple their birth weight in just 3 weeks on rich milk.",
            "They can recognise individual boat engines and voices.",
        ],
        bestSeason: "Year-round; pups born September – November",
        whereToSpot: "Rocky ledges on the eastern side of Coquet Island.",
        category: .marine
    ),
    WildlifeSpecies(
        id: "arctic-tern",
        name: "Arctic Tern",
        latinName: "Sterna paradisaea",
        emoji: "🕊️",
        description: "The ultimate long-distance traveller. Arctic terns migrate from Antarctica to Coquet Island each spring — a round trip of over 70,000 km. Watch these elegant, fork-tailed birds hover and plunge-dive for small fish in the waters around the island.",
        funFacts: [
            "Arctic terns see more daylight than any other creature — they chase the summer at both poles.",
            "They can live over 30 years.",
            "One tracked tern flew 96,000 km in a single year.",
            "They aggressively defend their nests — watch from a safe distance!",
        ],
        bestSeason: "May – August",
        whereToSpot: "Skimming the water surface near the island's northern shore.",
        category: .birds
    ),
    WildlifeSpecies(
        id: "roseate-tern",
        name: "Roseate Tern",
        latinName: "Sterna dougallii",
        emoji: "🪶",
        description: "Coquet Island hosts the UK's largest colony of roseate terns — one of Britain's rarest breeding seabirds. Their delicate pinkish breast feathers and graceful flight make them a photographer's dream. The RSPB wardens protect them around the clock.",
        funFacts: [
            "Coquet Island holds over 90% of the UK's breeding roseate terns.",
            "They nest in specially built nest boxes to protect them from gulls.",
            "Their name comes from the rosy flush on their breast plumage.",
            "They are strictly protected — landing on Coquet Island is prohibited.",
        ],
        bestSeason: "May – July",
        whereToSpot: "Nest boxes visible from the boat; look for the pink-tinged breast.",
        category: .birds
    ),
    WildlifeSpecies(
        id: "common-eider",
        name: "Common Eider",
        latinName: "Somateria mollissima",
        emoji: "🦆",
        description: "The UK's heaviest and fastest-flying duck. Eiders are famous for their soft down feathers, which the females pluck from their own breast to line their nests. Listen for their gentle, cooing 'ah-ooo' call drifting across the water.",
        funFacts: [
            "Eiderdown has been harvested sustainably in Northumberland for centuries.",
            "Females fast for the entire 26-day incubation period.",
            "Ducklings form crèches watched over by several females.",
            "They can fly at speeds up to 70 mph.",
        ],
        bestSeason: "Year-round; ducklings May – June",
        whereToSpot: "Close to shore around the island; often in large rafts on the water.",
        category: .birds
    ),
    WildlifeSpecies(
        id: "harbour-porpoise",
        name: "Harbour Porpoise",
        latinName: "Phocoena phocoena",
        emoji: "🐬",
        description: "Keep your eyes peeled for these shy, smaller cousins of dolphins. Harbour porpoises are regular visitors to the waters off Amble. You'll spot a brief glimpse of a small, dark triangular fin rolling through the water — no splash, no acrobatics, just a quiet, magical moment.",
        funFacts: [
            "Porpoises are about 1.5m long — much smaller than dolphins.",
            "They surface quietly without the splash dolphins are known for.",
            "They use echolocation clicks to hunt fish in murky water.",
            "Often seen alone or in small groups of 2–5.",
        ],
        bestSeason: "July – October (most frequent)",
        whereToSpot: "Open water between Amble Harbour and Coquet Island.",
        category: .marine
    ),
    WildlifeSpecies(
        id: "guillemot",
        name: "Common Guillemot",
        latinName: "Uria aalge",
        emoji: "🐦",
        description: "Guillemots crowd the cliff ledges of Coquet Island in dense, noisy colonies. These chocolate-brown 'flying penguins' stand upright on the rocks, laying a single pear-shaped egg directly on the bare ledge. Their pointed eggs are designed to roll in a circle rather than off the cliff.",
        funFacts: [
            "Guillemot eggs are pyriform (pear-shaped) to prevent them rolling off ledges.",
            "Each egg has a unique speckled pattern so parents recognise it.",
            "Chicks leap off the cliff into the sea before they can fly — at just 3 weeks old.",
            "The father stays with the chick at sea for up to 2 months.",
        ],
        bestSeason: "April – July",
        whereToSpot: "Dense clusters on the cliff ledges; look for the chocolate-brown backs.",
        category: .birds
    ),
    WildlifeSpecies(
        id: "kittiwake",
        name: "Kittiwake",
        latinName: "Rissa tridactyla",
        emoji: "🕊️",
        description: "The most graceful of the gulls, kittiwakes are true ocean-going seabirds that only come to land to breed. Their name comes from their distinctive 'kitti-waak' call. Unlike other gulls, they spend their winters far out in the North Atlantic.",
        funFacts: [
            "Kittiwakes are the only gull species that are truly pelagic (ocean-going).",
            "They build mud-and-grass nests on impossibly narrow cliff ledges.",
            "They have black legs — unlike the pink legs of most gulls.",
            "A kittiwake may fly over 1,000 km to find food for its chicks.",
        ],
        bestSeason: "April – August",
        whereToSpot: "Vertical cliff faces and ledges; listen for their namesake call.",
        category: .birds
    ),
]

// MARK: - Wildlife Guide View

struct WildlifeView: View {
    @State private var selectedCategory: WildlifeCategory? = nil

    private var filtered: [WildlifeSpecies] {
        guard let cat = selectedCategory else { return species }
        return species.filter { $0.category == cat }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            categoryFilter
            guideContent
        }
        .background(Theme.bg)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Wildlife Guide")
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(Theme.text)
            Text("Meet the residents of Coquet Island.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(nil, icon: "sparkles", label: "All")

                ForEach(WildlifeCategory.allCases, id: \.rawValue) { cat in
                    categoryChip(cat, icon: cat.icon, label: cat.rawValue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func categoryChip(_ cat: WildlifeCategory?, icon: String, label: String) -> some View {
        let isActive = selectedCategory == cat
        let color = cat?.color ?? Theme.sea

        return Button {
            withAnimation(.spring(response: 0.35)) { selectedCategory = cat }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(label)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(isActive ? .white : color)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isActive ? color : color.opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    private var guideContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, sp in
                    speciesCard(sp, index: idx)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    private func speciesCard(_ sp: WildlifeSpecies, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image area with gradient
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [sp.category.color, sp.category.color.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Decorative circles
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 100, height: 100)
                    .offset(x: 160, y: -30)

                Text(sp.emoji)
                    .font(.system(size: 72))
                    .offset(x: 180, y: -10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(sp.name)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(.white)
                    Text(sp.latinName)
                        .font(.system(size: 14, design: .serif))
                        .italic()
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
            .frame(height: 140)
            .clipped()

            // Details
            VStack(alignment: .leading, spacing: 14) {
                Text(sp.description)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.text)
                    .lineSpacing(4)

                // Quick info pills
                HStack(spacing: 8) {
                    infoPill(icon: "calendar", label: sp.bestSeason, color: Theme.puffin)
                    infoPill(icon: "mappin.and.ellipse", label: sp.whereToSpot, color: Theme.coral)
                }

                // Fun facts
                VStack(alignment: .leading, spacing: 6) {
                    Text("DID YOU KNOW?")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(sp.category.color)

                    ForEach(Array(sp.funFacts.enumerated()), id: \.offset) { i, fact in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(i + 1)")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(sp.category.color)
                                .clipShape(Circle())

                            Text(fact)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.text)
                                .lineSpacing(2)
                        }
                    }
                }
                .padding(14)
                .background(sp.category.color.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(18)
            .background(Theme.card)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.border))
        .shadow(color: Theme.deep.opacity(0.08), radius: 12, y: 6)
    }

    private func infoPill(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

#Preview {
    WildlifeView()
}
