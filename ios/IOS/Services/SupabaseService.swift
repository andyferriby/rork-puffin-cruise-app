import Foundation
import Supabase

@MainActor
final class SupabaseService: Sendable {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        let urlString = Config.EXPO_PUBLIC_SUPABASE_URL
        let key = Config.EXPO_PUBLIC_SUPABASE_ANON_KEY
        client = SupabaseClient(
            supabaseURL: URL(string: urlString)!,
            supabaseKey: key
        )
    }

    // MARK: - Schedule

    func fetchSchedule() async -> ScheduleConfig {
        do {
            let rows: [ConfigRow] = try await client
                .from("app_config")
                .select("value")
                .eq("key", value: "schedule")
                .limit(1)
                .execute()
                .value
            guard let row = rows.first else { return .default }
            return try JSONDecoder().decode(ScheduleConfig.self, from: JSONEncoder().encode(row.value))
        } catch {
            print("[schedule] fetch error:", error.localizedDescription)
            return .default
        }
    }

    func saveSchedule(_ config: ScheduleConfig) async throws {
        let body = ScheduleUpsert(key: "schedule", value: config, updatedAt: ISO8601DateFormatter().string(from: Date()))
        try await client
            .from("app_config")
            .upsert(body)
            .execute()
    }

    // MARK: - Photos

    func fetchPhotos() async -> [GalleryPhoto] {
        do {
            let response: [GalleryPhoto] = try await client
                .from("gallery_photos")
                .select("id, image_url, caption, guest_name, created_at")
                .eq("approved", value: true)
                .order("created_at", ascending: false)
                .limit(120)
                .execute()
                .value
            return response
        } catch {
            print("[gallery] fetch error:", error.localizedDescription)
            return []
        }
    }

    // MARK: - Bookings

    func fetchBookings(ids: [String]) async -> [Booking] {
        guard !ids.isEmpty else { return [] }
        do {
            let response: [Booking] = try await client
                .from("bookings")
                .select()
                .in("id", values: ids)
                .order("cruise_date", ascending: true)
                .execute()
                .value
            return response
        } catch {
            print("[bookings] fetch error:", error.localizedDescription)
            return []
        }
    }

    func fetchBookings(byEmail email: String) async -> [Booking] {
        do {
            let response: [Booking] = try await client
                .from("bookings")
                .select()
                .eq("customer_email", value: email.lowercased())
                .order("cruise_date", ascending: true)
                .execute()
                .value
            return response
        } catch {
            print("[bookings] fetch by email error:", error.localizedDescription)
            return []
        }
    }

    func fetchBooking(id: String) async -> Booking? {
        do {
            let response: [Booking] = try await client
                .from("bookings")
                .select()
                .eq("id", value: id)
                .limit(1)
                .execute()
                .value
            return response.first
        } catch {
            print("[bookings] fetch one error:", error.localizedDescription)
            return nil
        }
    }

    func checkInBooking(id: String) async throws {
        try await client
            .from("bookings")
            .update(["status": "checked_in"])
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Booking Counts (Spots)

    func fetchBookingCounts(for sailings: [(date: String, time: String, cruiseId: String)]) async -> [String: Int] {
        guard !sailings.isEmpty else { return [:] }
        do {
            let response: [BookingCountRow] = try await client
                .from("bookings")
                .select("cruise_date, cruise_time, cruise_id")
                .in("status", values: ["paid", "checked_in"])
                .execute()
                .value
            var result: [String: Int] = [:]
            for row in response {
                let key = "\(row.cruiseDate)|\(row.cruiseTime)|\(row.cruiseId)"
                result[key, default: 0] += 1
            }
            return result
        } catch {
            print("[spots] fetch counts error:", error.localizedDescription)
            return [:]
        }
    }

    // MARK: - Reviews

    func fetchReviews(for cruiseId: String) async -> [Review] {
        do {
            let response: [Review] = try await client
                .from("reviews")
                .select()
                .eq("cruise_id", value: cruiseId)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value
            return response
        } catch {
            print("[reviews] fetch error:", error.localizedDescription)
            return []
        }
    }

    func fetchReviews(forBooking bookingId: String) async -> Review? {
        do {
            let response: [Review] = try await client
                .from("reviews")
                .select()
                .eq("booking_id", value: bookingId)
                .limit(1)
                .execute()
                .value
            return response.first
        } catch {
            print("[reviews] fetch for booking error:", error.localizedDescription)
            return nil
        }
    }

    func fetchCruiseRatings(for cruiseIds: [String]) async -> [String: CruiseRating] {
        guard !cruiseIds.isEmpty else { return [:] }
        var result: [String: CruiseRating] = [:]
        for cid in cruiseIds {
            do {
                let response: [Review] = try await client
                    .from("reviews")
                    .select("rating")
                    .eq("cruise_id", value: cid)
                    .execute()
                    .value
                if !response.isEmpty {
                    let avg = Double(response.reduce(0) { $0 + $1.rating }) / Double(response.count)
                    result[cid] = CruiseRating(cruiseId: cid, averageRating: avg, reviewCount: response.count)
                }
            } catch {
                print("[ratings] fetch error for \(cid):", error.localizedDescription)
            }
        }
        return result
    }

    func submitReview(_ review: ReviewInsert) async throws {
        try await client
            .from("reviews")
            .insert(review)
            .execute()
    }

    // MARK: - Notifications

    func fetchNotifications() async -> [NotificationRecord] {
        do {
            let response: [NotificationRecord] = try await client
                .from("notifications")
                .select()
                .order("sent_at", ascending: false)
                .limit(50)
                .execute()
                .value
            return response
        } catch {
            print("[notifications] fetch error:", error.localizedDescription)
            return []
        }
    }

    // MARK: - Photo Upload

    func uploadPhoto(data: Data, contentType: String, caption: String?, guestName: String?) async throws {
        let ext = contentType.contains("png") ? "png" : "jpg"
        let path = "\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(6)).\(ext)"

        try await client.storage
            .from("gallery")
            .upload(path, data: data, options: .init(contentType: contentType))

        let publicURL = try client.storage.from("gallery").getPublicURL(path: path)

        let insert = PhotoInsert(
            imageURL: publicURL.absoluteString,
            caption: caption,
            guestName: guestName
        )
        try await client
            .from("gallery_photos")
            .insert(insert)
            .execute()
    }
}

// MARK: - Codable Helpers

private struct ConfigRow: Codable {
    let value: ScheduleConfig
}

private struct BookingCountRow: Codable {
    let cruiseDate: String
    let cruiseTime: String
    let cruiseId: String

    enum CodingKeys: String, CodingKey {
        case cruiseDate = "cruise_date"
        case cruiseTime = "cruise_time"
        case cruiseId = "cruise_id"
    }
}

private struct ScheduleUpsert: Codable {
    let key: String
    let value: ScheduleConfig
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case key, value
        case updatedAt = "updated_at"
    }
}

private struct PhotoInsert: Codable {
    let imageURL: String
    let caption: String?
    let guestName: String?

    enum CodingKeys: String, CodingKey {
        case imageURL = "image_url"
        case caption
        case guestName = "guest_name"
    }
}
