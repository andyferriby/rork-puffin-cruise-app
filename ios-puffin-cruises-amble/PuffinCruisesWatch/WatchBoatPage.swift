import SwiftUI
import MapKit

nonisolated struct WatchBoatLocation: Decodable, Hashable {
    let latitude: Double
    let longitude: Double
    let heading: Double?
    let speed: Double?
    let updatedAt: String
    let isTracking: Bool
}

/// Reads the crew-updated boat position from the same Supabase app_config
/// key the iPhone app and admin tools use.
nonisolated enum WatchBoatService {
    private static let supabaseURL = "https://hizgugsvbkzjrjsaaxkd.supabase.co"
    private static let anonKey = "sb_publishable_g6zekmj_iMcihX5nycHKJQ_x8lCRnhW"

    static func fetch() async -> WatchBoatLocation? {
        guard var components = URLComponents(string: "\(supabaseURL)/rest/v1/app_config") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "select", value: "value"),
            URLQueryItem(name: "key", value: "eq.boat_location")
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            struct ConfigRow: Decodable { let value: WatchBoatLocation }
            return try JSONDecoder().decode([ConfigRow].self, from: data).first?.value
        } catch {
            print("[boat] fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    nonisolated static func parseUpdated(_ string: String) -> Date? {
        let plain = ISO8601DateFormatter()
        if let date = plain.date(from: string) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: string)
    }
}

@MainActor
@Observable
final class BoatModel {
    private(set) var location: WatchBoatLocation?
    private(set) var hasLoaded = false

    func runPolling() async {
        while !Task.isCancelled {
            location = await WatchBoatService.fetch()
            hasLoaded = true
            try? await Task.sleep(for: .seconds(15))
        }
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let location else { return nil }
        return CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }

    var speedKnots: Double? { location?.speed.map { $0 * 1.94384 } }

    var distanceFromPierKm: Double? {
        guard let location else { return nil }
        let pierLat = 55.3338, pierLon = -1.5803
        let dLat = (location.latitude - pierLat) * .pi / 180
        let dLon = (location.longitude - pierLon) * .pi / 180
        let lat1 = pierLat * .pi / 180
        let lat2 = location.latitude * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 6371 * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

struct BoatPage: View {
    @State private var model = BoatModel()
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                WatchPageHeader(icon: "location.fill", title: "Boat Tracker")
                if model.hasLoaded, model.location == nil {
                    WatchStatusCard(
                        icon: "antenna.radiowaves.left.and.right.slash",
                        title: "No live position",
                        detail: "The crew's tracker isn't broadcasting right now."
                    )
                } else if let location = model.location, let coordinate = model.coordinate {
                    mapCard(coordinate)
                    statsCard(location)
                } else {
                    WatchStatusCard(icon: "hourglass", title: "Finding the boat…", detail: "Checking the crew's live tracker.")
                }
            }
            .padding(.horizontal, 4)
        }
        .background(WatchPageBackground())
        .task {
            await model.runPolling()
        }
        .onChange(of: model.location) {
            if let coordinate = model.coordinate {
                camera = .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                ))
            }
        }
    }

    private func mapCard(_ coordinate: CLLocationCoordinate2D) -> some View {
        Map(position: $camera) {
            Marker("Puffin Cruises", coordinate: coordinate)
                .tint(WatchTheme.gold)
        }
        .frame(height: 120)
        .clipShape(.rect(cornerRadius: 12))
    }

    private func statsCard(_ location: WatchBoatLocation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Circle()
                    .fill(location.isTracking ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(location.isTracking ? "At sea — live" : "Tracker off")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                if let updated = WatchBoatService.parseUpdated(location.updatedAt) {
                    Text(updated, style: .relative)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            statRow(icon: "speedometer", label: speedText)
            statRow(icon: "safari", label: headingText)
            statRow(icon: "point.topleft.down.curvedto.point.bottomright.up", label: distanceText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .watchCard()
    }

    private var speedText: String {
        guard let knots = model.speedKnots else { return "Moored" }
        return String(format: "%.1f knots", knots)
    }

    private var headingText: String {
        guard let heading = model.location?.heading else { return "Heading unknown" }
        return String(format: "%@ (%.0f°)", compassName(heading), heading)
    }

    private var distanceText: String {
        guard let distance = model.distanceFromPierKm else { return "Distance unknown" }
        return distance < 0.2
            ? "At the boarding pier"
            : String(format: "%.1f km from the pier", distance)
    }

    private func statRow(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(WatchTheme.gold)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            Spacer(minLength: 0)
        }
    }

    private func compassName(_ degrees: Double) -> String {
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((degrees + 22.5) / 45) % 8
        return points[index]
    }
}
