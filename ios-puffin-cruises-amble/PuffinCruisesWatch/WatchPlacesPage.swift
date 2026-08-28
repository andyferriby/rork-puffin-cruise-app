import SwiftUI
import WatchKit

/// "Places to Eat" on the watch — crew-managed list with one-tap walking
/// directions handed off to Apple Maps.
struct PlacesPage: View {
    @State private var places: [WatchPlace] = []
    @State private var hasLoaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                WatchPageHeader(icon: "fork.knife", title: "Places to Eat")
                if hasLoaded, places.isEmpty {
                    WatchStatusCard(
                        icon: "fork.knife.circle",
                        title: "No places yet",
                        detail: "Crew can add places in the admin panel."
                    )
                } else if !hasLoaded && places.isEmpty {
                    WatchStatusCard(icon: "hourglass", title: "Loading…", detail: "Fetching the harbour's best food stops.")
                } else {
                    ForEach(places) { place in
                        NavigationLink {
                            PlaceDetailPage(place: place)
                        } label: {
                            HStack(alignment: .center, spacing: 6) {
                                placeThumbnail(place)
                                VStack(alignment: .leading, spacing: 3) {
                                    if let category = place.category, !category.isEmpty {
                                        Text(category.uppercased())
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(WatchTheme.gold)
                                    }
                                    Text(place.name)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                    if let blurb = place.blurb, !blurb.isEmpty {
                                        Text(blurb)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.white.opacity(0.7))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .watchCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .background(WatchPageBackground())
        .task {
            places = await WatchPlacesService.fetchPlaces()
            hasLoaded = true
        }
        .refreshable {
            places = await WatchPlacesService.fetchPlaces()
        }
    }

    /// Small rounded photo in the listing row; falls back to a cutlery glyph.
    @ViewBuilder
    private func placeThumbnail(_ place: WatchPlace) -> some View {
        if let urlString = place.imageURL, let url = URL(string: urlString) {
            Color.white.opacity(0.12)
                .frame(width: 36, height: 36)
                .overlay {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                        default:
                            Image(systemName: "fork.knife")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(WatchTheme.gold)
                        }
                    }
                }
                .clipShape(.rect(cornerRadius: 9))
        }
    }
}

private struct PlaceDetailPage: View {
    let place: WatchPlace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                WatchPageHeader(icon: "fork.knife", title: place.name)
                if let urlString = place.imageURL, let url = URL(string: urlString) {
                    Color.white.opacity(0.1)
                        .frame(height: 70)
                        .overlay {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                                default:
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(WatchTheme.gold)
                                }
                            }
                        }
                        .clipShape(.rect(cornerRadius: 12))
                }
                if let blurb = place.blurb, !blurb.isEmpty {
                    Text(blurb)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(WatchTheme.mint)
                }
                if let info = place.info, !info.isEmpty {
                    Text(info)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Button {
                    openDirections()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Directions")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(WatchTheme.gold))
                }
                .buttonStyle(.plain)

                if let phone = place.phone, !phone.isEmpty {
                    Button {
                        let cleanNumber = phone.replacingOccurrences(of: " ", with: "")
                        if let phoneURL = URL(string: "tel:\(cleanNumber)") {
                            WKExtension.shared().openSystemURL(phoneURL)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text(phone)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(.white.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .background(WatchPageBackground())
    }

    /// Hands off to Apple Maps with walking directions to the place.
    private func openDirections() {
        guard let url = URL(string: "https://maps.apple.com/?daddr=\(place.latitude),\(place.longitude)&dirflg=w") else {
            return
        }
        WKExtension.shared().openSystemURL(url)
    }
}
