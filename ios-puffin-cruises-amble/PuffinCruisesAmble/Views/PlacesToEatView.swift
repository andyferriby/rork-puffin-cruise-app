import MapKit
import SwiftUI

/// "Places to Eat" — crew-managed list from the admin panel, with one-tap
/// walking directions via Apple Maps and a favourites tab for top picks.
struct PlacesToEatView: View {
    private enum PlacesTab: String, CaseIterable {
        case all = "All Places"
        case favourites = "My Favourites"
    }

    @State private var places: [PlaceToEat] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var tab: PlacesTab = .all
    private let favorites = FavoritesStore.shared

    private var visiblePlaces: [PlaceToEat] {
        tab == .all ? places : places.filter { favorites.isFavorite($0) }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading places…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if loadFailed || places.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.textMuted)
                    Text(loadFailed ? "Couldn't load places" : "No places added yet")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text("Crew can add places in the admin panel.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Picker("Tab", selection: $tab) {
                        ForEach(PlacesTab.allCases, id: \.self) { value in
                            Text(value.rawValue).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    if visiblePlaces.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "heart")
                                .font(.system(size: 44))
                                .foregroundStyle(Theme.textMuted)
                            Text("No favourites yet")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Theme.text)
                            Text("Tap the heart on a place to save it here.")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textMuted)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(visiblePlaces) { place in
                                    NavigationLink(value: place) {
                                        placeCard(place)
                                    }
                                    .buttonStyle(.plain)
                                    .overlay(alignment: .topTrailing) {
                                        heartButton(place)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 2)
                            .padding(.bottom, 32)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: favorites.favoriteIDs)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .background(Theme.bg)
        .navigationTitle("Places to Eat")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .navigationDestination(for: PlaceToEat.self) { place in
            PlaceDetailView(place: place)
        }
    }

    /// Heart toggle, laid over the card so the tap never triggers navigation.
    private func heartButton(_ place: PlaceToEat) -> some View {
        let isFavorite = favorites.isFavorite(place)
        return Button {
            favorites.toggle(place)
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isFavorite ? Theme.coral : Theme.sea)
                .frame(width: 38, height: 38)
                .background(.white.opacity(0.92))
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(Theme.border, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
                .scaleEffect(isFavorite ? 1.0 : 0.95)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFavorite ? "Remove from favourites" : "Add to favourites")
        .padding(.top, 6)
        .padding(.trailing, 10)
    }

    private func load() async {
        isLoading = places.isEmpty
        loadFailed = false
        let fetched = await SupabaseService.fetchPlacesToEat()
        places = fetched
        loadFailed = fetched.isEmpty
        isLoading = false
    }

    private func placeCard(_ place: PlaceToEat) -> some View {
        HStack(spacing: 14) {
            Color(Theme.foam)
                .frame(width: 64, height: 64)
                .overlay {
                    if let imageURL = place.imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                            default:
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Theme.sea)
                            }
                        }
                    } else {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.sea)
                    }
                }
                .clipShape(.rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 2) {
                if !place.category.isEmpty {
                    Text(place.category.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(Theme.sea)
                }
                Text(place.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.text)
                if !place.blurb.isEmpty {
                    Text(place.blurb)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textMuted)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(12)
        .puffinCard(radius: 18, fill: .white)
    }
}

/// Detail for a single place: info, call, website and walking directions.
struct PlaceDetailView: View {
    let place: PlaceToEat
    private let favorites = FavoritesStore.shared

    private var directionsURL: URL? {
        URL(string: "https://maps.apple.com/?daddr=\(place.latitude),\(place.longitude)&dirflg=w")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let imageURL = place.imageURL, let url = URL(string: imageURL) {
                    Color(Theme.foam)
                        .frame(height: 200)
                        .overlay {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                                default:
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 36))
                                        .foregroundStyle(Theme.sea)
                                }
                            }
                        }
                        .clipShape(.rect(cornerRadius: 18))
                }

                VStack(alignment: .leading, spacing: 4) {
                    if !place.category.isEmpty {
                        Text(place.category.uppercased())
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(Theme.sea)
                    }
                    Text(place.name)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(Theme.text)
                }

                if !place.blurb.isEmpty {
                    Text(place.blurb)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.sea)
                }

                if !place.info.isEmpty {
                    Text(place.info)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textMuted)
                        .lineSpacing(4)
                }

                if let directionsURL {
                    Button {
                        UIApplication.shared.open(directionsURL)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                            Text("Get Directions").font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.sea)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                }

                if let phone = place.phone, !phone.isEmpty {
                    Link(destination: URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") ?? URL(string: "tel:0")!) {
                        HStack(spacing: 8) {
                            Image(systemName: "phone.fill")
                            Text(phone).font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Theme.sea)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.foam)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                }

                if let website = place.website, !website.isEmpty, let url = URL(string: website) {
                    Link(destination: url) {
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                            Text("Visit website").font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Theme.sea)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.foam)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Theme.bg)
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favorites.toggle(place)
                } label: {
                    Image(systemName: favorites.isFavorite(place) ? "heart.fill" : "heart")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(favorites.isFavorite(place) ? Theme.coral : Theme.sea)
                }
                .accessibilityLabel(favorites.isFavorite(place) ? "Remove from favourites" : "Add to favourites")
            }
        }
    }
}
