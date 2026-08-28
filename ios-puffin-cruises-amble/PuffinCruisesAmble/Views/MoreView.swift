import SwiftUI

private struct MoreItem: Identifiable, Hashable {
    let id: String
    let label: String
    let desc: String
    let icon: String
    let tint: Color
}

private struct MoreSection: Identifiable {
    let id: String
    let title: String
    let items: [MoreItem]
}

struct MoreView: View {
    @Environment(AppSettings.self) private var settings

    private let sections: [MoreSection] = [
        MoreSection(id: "visit", title: "Your Visit", items: [
            MoreItem(id: "tickets", label: "My Tickets", desc: "View your boarding passes", icon: "ticket.fill", tint: Theme.coral),
            MoreItem(id: "trip", label: "Live Trip", desc: "Follow the boat in real time", icon: "safari.fill", tint: Theme.wave),
            MoreItem(id: "map", label: "Map", desc: "Find us at Amble Harbour", icon: "map.fill", tint: Theme.sea),
            MoreItem(id: "cameras", label: "Live Cameras", desc: "See the harbour right now", icon: "video.fill", tint: Theme.puffin)
        ]),
        MoreSection(id: "explore", title: "Explore", items: [
            MoreItem(id: "wildlife", label: "Wildlife", desc: "Puffins, seals and more", icon: "bird.fill", tint: Theme.sandDeep),
            MoreItem(id: "gallery", label: "Gallery", desc: "Photos from the water", icon: "photo.on.rectangle.angled", tint: Theme.sea),
            MoreItem(id: "shop", label: "Shop", desc: "Gifts and merchandise", icon: "bag.fill", tint: Theme.coral)
        ]),
        MoreSection(id: "account", title: "Account", items: [
            MoreItem(id: "profile", label: "Profile", desc: "Settings and preferences", icon: "person.fill", tint: Theme.sea),
            MoreItem(id: "admin", label: "Crew Admin", desc: "Scanner and schedule tools", icon: "shield.fill", tint: Theme.ink)
        ])
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("More")
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(Theme.text)
                        Text("Everything for your day at Amble")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .padding(.bottom, 4)

                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title.uppercased())
                                .font(.system(size: 12, weight: .heavy))
                                .tracking(1)
                                .foregroundStyle(Theme.textMuted)
                                .padding(.leading, 4)

                            VStack(spacing: 0) {
                                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                                    if item.id == "admin" {
                                        Button { settings.showAdmin = true } label: { row(item) }
                                            .buttonStyle(.plain)
                                    } else {
                                        NavigationLink(value: item) { row(item) }
                                            .buttonStyle(.plain)
                                    }
                                    if index < section.items.count - 1 {
                                        Rectangle().fill(Theme.border).frame(height: 1)
                                    }
                                }
                            }
                            .puffinCard(radius: 18, fill: .white)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Theme.bg)
            .navigationDestination(for: MoreItem.self) { item in
                destination(for: item.id)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func row(_ item: MoreItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 18))
                .foregroundStyle(item.tint)
                .frame(width: 40, height: 40)
                .background(item.tint.opacity(0.12))
                .clipShape(.rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text(item.desc)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(.rect)
    }

    @ViewBuilder
    private func destination(for id: String) -> some View {
        switch id {
        case "tickets": TicketsView()
        case "trip": TripView()
        case "map": HarbourMapView()
        case "cameras": CamerasView()
        case "wildlife": WildlifeView()
        case "gallery": GalleryView()
        case "shop": ShopView()
        case "profile": ProfileView()
        default: EmptyView()
        }
    }
}
