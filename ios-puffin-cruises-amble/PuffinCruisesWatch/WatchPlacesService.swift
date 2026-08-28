import Foundation

/// A place to eat, fetched from the same Supabase `app_config` key the iPhone
/// app and crew admin tools use.
nonisolated struct WatchPlace: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String?
    let blurb: String?
    let info: String?
    let latitude: Double
    let longitude: Double
    let phone: String?
    let website: String?
    let imageURL: String?
    let gallery: [String]?
}

/// Minimal fetch for the watch app — talks to Supabase REST directly using the
/// public project URL and publishable anon key (the watch cannot import the
/// iPhone app's services).
nonisolated enum WatchPlacesService {
    private static let supabaseURL = "https://hizgugsvbkzjrjsaaxkd.supabase.co"
    private static let anonKey = "sb_publishable_g6zekmj_iMcihX5nycHKJQ_x8lCRnhW"

    static func fetchPlaces() async -> [WatchPlace] {
        guard var components = URLComponents(string: "\(supabaseURL)/rest/v1/app_config") else {
            return []
        }
        components.queryItems = [
            URLQueryItem(name: "select", value: "value"),
            URLQueryItem(name: "key", value: "eq.places_to_eat")
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            struct ConfigRow: Decodable { let value: [WatchPlace] }
            return try JSONDecoder().decode([ConfigRow].self, from: data).first?.value ?? []
        } catch {
            print("[watch-places] fetch failed: \(error.localizedDescription)")
            return []
        }
    }
}
