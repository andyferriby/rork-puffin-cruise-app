import SwiftUI
import MapKit

// MARK: - Map Location Model

struct MapLocation: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    let icon: String
    let color: Color
    let category: LocationCategory

    static func == (lhs: MapLocation, rhs: MapLocation) -> Bool {
        lhs.id == rhs.id
    }
}

enum LocationCategory: String, CaseIterable, Equatable {
    case harbour = "Harbour"
    case wildlife = "Wildlife"
    case landmark = "Landmark"

    var icon: String {
        switch self {
        case .harbour: return "ferry.fill"
        case .wildlife: return "pawprint.fill"
        case .landmark: return "mappin.and.ellipse"
        }
    }
}

private let locations: [MapLocation] = [
    MapLocation(
        id: "booking-office",
        name: "Booking Office",
        subtitle: "Amble Harbour Village — buy tickets in person",
        coordinate: CLLocationCoordinate2D(latitude: 55.3336, longitude: -1.5812),
        icon: "ticket.fill",
        color: Theme.coral,
        category: .harbour
    ),
    MapLocation(
        id: "pier",
        name: "Boarding Pier",
        subtitle: "Where the boat departs — arrive 15 min early",
        coordinate: CLLocationCoordinate2D(latitude: 55.3338, longitude: -1.5803),
        icon: "ferry.fill",
        color: Theme.sea,
        category: .harbour
    ),
    MapLocation(
        id: "parking",
        name: "Harbour Parking",
        subtitle: "Free parking for Puffin Cruises customers",
        coordinate: CLLocationCoordinate2D(latitude: 55.3340, longitude: -1.5825),
        icon: "car.fill",
        color: Theme.textMuted,
        category: .harbour
    ),
    MapLocation(
        id: "coquet-island",
        name: "Coquet Island",
        subtitle: "RSPB reserve — home to 45,000 puffins",
        coordinate: CLLocationCoordinate2D(latitude: 55.3360, longitude: -1.5400),
        icon: "bird.fill",
        color: Theme.puffin,
        category: .wildlife
    ),
    MapLocation(
        id: "puffin-colony",
        name: "Puffin Colony",
        subtitle: "Best viewing from the northern approach",
        coordinate: CLLocationCoordinate2D(latitude: 55.3380, longitude: -1.5385),
        icon: "bird.fill",
        color: Theme.sea,
        category: .wildlife
    ),
    MapLocation(
        id: "seal-rocks",
        name: "Seal Rocks",
        subtitle: "Grey seal haul-out — visible year-round",
        coordinate: CLLocationCoordinate2D(latitude: 55.3345, longitude: -1.5425),
        icon: "pawprint.fill",
        color: Theme.wave,
        category: .wildlife
    ),
    MapLocation(
        id: "ambre-marina",
        name: "Amble Marina",
        subtitle: "Shops, cafés and the Sunday market",
        coordinate: CLLocationCoordinate2D(latitude: 55.3325, longitude: -1.5830),
        icon: "cup.and.saucer.fill",
        color: Theme.sandDeep,
        category: .landmark
    ),
    MapLocation(
        id: "warkworth-castle",
        name: "Warkworth Castle",
        subtitle: "Medieval castle 1.5 miles from the harbour",
        coordinate: CLLocationCoordinate2D(latitude: 55.3450, longitude: -1.6120),
        icon: "building.columns.fill",
        color: Theme.text,
        category: .landmark
    ),
]

// MARK: - Map View

struct MapView: View {
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 55.3350, longitude: -1.5610),
        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
    ))
    @State private var selectedLocation: MapLocation?
    @State private var selectedCategory: LocationCategory? = nil

    private var filtered: [MapLocation] {
        guard let cat = selectedCategory else { return locations }
        return locations.filter { $0.category == cat }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            categoryFilter

            ZStack(alignment: .bottom) {
                mapContent

                if let loc = selectedLocation {
                    locationCard(loc)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .background(Theme.bg)
        .animation(.spring(response: 0.4), value: selectedLocation)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Map")
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(Theme.text)
            Text("Find us at Amble Harbour and explore the route.")
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
                categoryChip(nil, label: "All")

                ForEach(LocationCategory.allCases, id: \.rawValue) { cat in
                    categoryChip(cat, label: cat.rawValue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func categoryChip(_ cat: LocationCategory?, label: String) -> some View {
        let isActive = selectedCategory == cat
        return Button {
            withAnimation(.spring(response: 0.35)) { selectedCategory = cat }
        } label: {
            HStack(spacing: 6) {
                if let icon = cat?.icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(label)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(isActive ? .white : Theme.sea)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isActive ? Theme.sea : Theme.sea.opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Map

    private var mapContent: some View {
        Map(position: $camera, selection: Binding(
            get: { selectedLocation?.id },
            set: { newId in
                if let id = newId, let loc = locations.first(where: { $0.id == id }) {
                    withAnimation { selectedLocation = loc }
                }
            }
        )) {
            ForEach(filtered) { loc in
                Annotation(loc.name, coordinate: loc.coordinate) {
                    mapPin(loc)
                }
            }

            // Route line: harbour to Coquet Island
            MapPolyline(coordinates: [
                CLLocationCoordinate2D(latitude: 55.3338, longitude: -1.5803),
                CLLocationCoordinate2D(latitude: 55.3360, longitude: -1.5400),
            ])
            .stroke(Theme.sea.opacity(0.35), lineWidth: 3)
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 20,
                topTrailingRadius: 20,
                style: .continuous
            )
        )
        .frame(maxHeight: .infinity)
    }

    private func mapPin(_ loc: MapLocation) -> some View {
        VStack(spacing: 0) {
            Image(systemName: loc.icon)
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(loc.color)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                .shadow(color: loc.color.opacity(0.4), radius: 6, y: 3)

            Image(systemName: "triangle.fill")
                .font(.system(size: 8))
                .foregroundStyle(loc.color)
                .offset(y: -3)
        }
        .onTapGesture {
            withAnimation { selectedLocation = loc }
        }
    }

    // MARK: - Location Card

    private func locationCard(_ loc: MapLocation) -> some View {
        HStack(spacing: 14) {
            Image(systemName: loc.icon)
                .font(.system(size: 20))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(loc.color)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 2) {
                Text(loc.name)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Theme.text)
                Text(loc.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                openInMaps(loc)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 14))
                    Text("Go")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(loc.color)
                .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Theme.deep.opacity(0.14), radius: 16, y: 8)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .onTapGesture {
            withAnimation { selectedLocation = nil }
        }
    }

    private func openInMaps(_ loc: MapLocation) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: loc.coordinate))
        item.name = loc.name
        item.openInMaps()
    }
}

#Preview {
    MapView()
}
