import Foundation
import UIKit

/// Guest's saved Places to Eat, persisted locally so their top picks survive
/// app restarts. Shared by the list, the detail screen and the favourites tab.
@MainActor
@Observable
final class FavoritesStore {
    static let shared = FavoritesStore()

    private static let defaultsKey = "favouritePlaceIDs"

    private(set) var favoriteIDs: Set<String> = []

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.defaultsKey),
           let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            favoriteIDs = Set(decoded)
        }
    }

    func isFavorite(_ place: PlaceToEat) -> Bool {
        favoriteIDs.contains(place.id)
    }

    func toggle(_ place: PlaceToEat) {
        if favoriteIDs.contains(place.id) {
            favoriteIDs.remove(place.id)
        } else {
            favoriteIDs.insert(place.id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        persist()
    }

    private func persist() {
        let sorted = favoriteIDs.sorted()
        if let data = try? JSONEncoder().encode(sorted),
           let raw = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(raw, forKey: Self.defaultsKey)
        }
    }
}
