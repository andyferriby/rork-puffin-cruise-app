import MapKit
import SwiftUI

private struct Place: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    let icon: String
    let color: Color
    let category: String

    static func == (lhs: Place, rhs: Place) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct HarbourMapView: View {
    @State private var filter = "All"
    @State private var selected: Place?
    @State private var boat: BoatLocation?
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 55.335, longitude: -1.561),
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
    )

    private let filters = ["All", "Sailing", "Parking", "Dining", "Landmark"]

    private let places: [Place] = [
        Place(id: "office", title: "Booking Office", subtitle: "Check in 20 mins early at Amble Harbour Village",
              coordinate: .init(latitude: 55.3336, longitude: -1.5812), icon: "ferry.fill", color: Theme.coral, category: "Sailing"),
        Place(id: "pier", title: "Boarding Pier", subtitle: "Crew scan QR tickets here — arrive 15 min early",
              coordinate: .init(latitude: 55.3338, longitude: -1.5803), icon: "location.north.fill", color: Theme.sea, category: "Sailing"),
        Place(id: "harbour", title: "Harbour Car Park", subtitle: "Closest parking · NE65 0AP — free for Puffin Cruises guests",
              coordinate: .init(latitude: 55.334, longitude: -1.5825), icon: "car.fill", color: Theme.textMuted, category: "Parking"),
        Place(id: "boathouse", title: "The Old Boathouse", subtitle: "Seafood restaurant on the harbour front · 1 min walk",
              coordinate: .init(latitude: 55.3331, longitude: -1.5828), icon: "fork.knife", color: Theme.puffin, category: "Dining"),
        Place(id: "coquet", title: "Coquet Island", subtitle: "RSPB reserve — puffins, seals & historic lighthouse",
              coordinate: .init(latitude: 55.336, longitude: -1.54), icon: "mappin", color: Theme.puffin, category: "Landmark")
    ]

    private var visible: [Place] {
        filter == "All" ? places : places.filter { $0.category == filter }
    }

    private var isBoatHidden: Bool { boat?.isHidden == true }
    private var isBoatLive: Bool { boat?.isTracking == true && !isBoatHidden }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position) {
                MapPolyline(coordinates: [
                    CLLocationCoordinate2D(latitude: 55.3338, longitude: -1.5803),
                    CLLocationCoordinate2D(latitude: 55.336, longitude: -1.54)
                ])
                .stroke(Theme.wave.opacity(0.8), style: StrokeStyle(lineWidth: 3, dash: [8, 6]))

                ForEach(visible) { place in
                    Annotation(place.title, coordinate: place.coordinate) {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selected = place }
                        } label: {
                            Image(systemName: place.icon)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(place.color)
                                .clipShape(.circle)
                                .overlay { Circle().stroke(.white, lineWidth: 2) }
                                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                        }
                    }
                }

                if let boat, boat.isTracking, !isBoatHidden {
                    Annotation("Puffin Cruiser", coordinate: .init(latitude: boat.latitude, longitude: boat.longitude)) {
                        ZStack {
                            Circle().fill(Theme.coral.opacity(0.25)).frame(width: 46, height: 46)
                            Image(systemName: "ferry.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Theme.coral)
                                .clipShape(.circle)
                                .overlay { Circle().stroke(.white, lineWidth: 2) }
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea()

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: isBoatHidden ? "eye.slash" : "dot.radiowaves.left.and.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isBoatLive ? Theme.coral : Theme.textMuted)
                    Text(isBoatHidden ? "Live tracking hidden for a private charter" : isBoatLive ? "Boat tracking live" : "Boat not sailing right now")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(.regularMaterial)
                .clipShape(.rect(cornerRadius: 14))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.self) { item in
                            Button {
                                withAnimation { filter = item }
                            } label: {
                                Text(item)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(filter == item ? .white : Theme.sea)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(filter == item ? Theme.sea : Color.white)
                                    .clipShape(.capsule)
                                    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            if let selected {
                placeCard(selected)
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            boat = await SupabaseService.fetchBoatLocation()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                boat = await SupabaseService.fetchBoatLocation()
            }
        }
    }

    private func placeCard(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: place.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(place.color)
                    .clipShape(.rect(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text(place.title).font(.system(size: 17, weight: .black)).foregroundStyle(Theme.text)
                    Text(place.subtitle).font(.system(size: 13)).foregroundStyle(Theme.textMuted).lineSpacing(3)
                }
                Spacer(minLength: 0)
                Button {
                    withAnimation { selected = nil }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textMuted)
                        .frame(width: 30, height: 30)
                        .background(Theme.foam)
                        .clipShape(.circle)
                }
            }

            Button {
                let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
                item.name = place.title
                item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                    Text("Get directions").font(.system(size: 15, weight: .black))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Theme.sea)
                .clipShape(.rect(cornerRadius: 14))
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: 22))
        .padding(16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
