import Foundation

/// A place to eat or drink around Amble harbour, managed by crew in the
/// admin panel and stored in Supabase `app_config` under `places_to_eat`.
nonisolated struct PlaceToEat: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var category: String
    var blurb: String
    var info: String
    var latitude: Double
    var longitude: Double
    var imageURL: String?
    var phone: String?
    var website: String?
}

/// One of the four bundled narrated stories in The Talking Harbour.
/// The MP3 files ship inside the app bundle, so stories play fully offline.
nonisolated struct HarbourStory: Identifiable, Hashable {
    let id: String
    let title: String
    let blurb: String
    let resource: String
    let latitude: Double
    let longitude: Double

    var coordinate: (latitude: Double, longitude: Double) { (latitude, longitude) }
}

nonisolated enum HarbourStories {
    /// The four narrated stories, in walk order from the harbour.
    static let all: [HarbourStory] = [
        HarbourStory(
            id: "lifeboat",
            title: "The Lifeboat Crews",
            blurb: "150 years of Amble's bravest, from oars and sails to today's crews.",
            resource: "amble_lifeboat_history",
            latitude: 55.3330,
            longitude: -1.5835
        ),
        HarbourStory(
            id: "coaling",
            title: "The Coaling Days",
            blurb: "When Amble roared as one of the busiest coal ports on the coast.",
            resource: "amble_coal_history_narration",
            latitude: 55.3345,
            longitude: -1.5820
        ),
        HarbourStory(
            id: "puffins",
            title: "Coquet Island's Puffins",
            blurb: "The green island on the horizon and the birds that rule it.",
            resource: "coquet_island_voice",
            latitude: 55.3332,
            longitude: -1.5782
        ),
        HarbourStory(
            id: "castle",
            title: "Warkworth Castle",
            blurb: "The Percy stronghold a mile up the river, and its oldest ghost story.",
            resource: "warkworth_castle_narrator",
            latitude: 55.3467,
            longitude: -1.6121
        )
    ]

    static func story(id: String) -> HarbourStory? {
        all.first { $0.id == id }
    }
}
