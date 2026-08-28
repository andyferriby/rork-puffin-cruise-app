import Foundation

nonisolated enum SupabaseError: LocalizedError {
    case notConfigured
    case badResponse(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase is not configured."
        case let .badResponse(status, body):
            return "Request failed (\(status)). \(body)"
        }
    }
}

nonisolated struct SupabaseConfigRow<T: Decodable>: Decodable {
    let value: T
}

nonisolated struct SupabaseConfigWrite<V: Encodable>: Encodable {
    let key: String
    let value: V
    let updated_at: String
}

nonisolated struct BookingStatusPatch: Encodable {
    let status: String
}

nonisolated struct PushTokenRow: Decodable {
    let token: String
}

nonisolated struct PushTokenUpsert: Encodable {
    let token: String
    let platform: String
}

/// Thin REST wrapper around the same Supabase project the Expo app uses.
/// Stays MainActor-isolated (project default) so it can read `Config`;
/// every network call suspends off the main thread inside URLSession.
enum SupabaseService {
    private static var baseURL: String {
        Config.EXPO_PUBLIC_SUPABASE_URL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static var anonKey: String {
        Config.EXPO_PUBLIC_SUPABASE_ANON_KEY.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var isConfigured: Bool { !baseURL.isEmpty && !anonKey.isEmpty }

    private static func makeRequest(
        path: String,
        query: [URLQueryItem],
        method: String,
        body: Data?,
        prefer: String?
    ) throws -> URLRequest {
        guard isConfigured, var components = URLComponents(string: "\(baseURL)/rest/v1/\(path)") else {
            throw SupabaseError.notConfigured
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw SupabaseError.notConfigured }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }
        request.httpBody = body
        return request
    }

    @discardableResult
    static func send(
        path: String,
        query: [URLQueryItem] = [],
        method: String = "GET",
        body: Data? = nil,
        prefer: String? = nil
    ) async throws -> Data {
        let request = try makeRequest(path: path, query: query, method: method, body: body, prefer: prefer)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return data }
        guard (200..<300).contains(http.statusCode) else {
            throw SupabaseError.badResponse(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    static func fetch<T: Decodable>(
        _ type: T.Type,
        path: String,
        query: [URLQueryItem]
    ) async throws -> [T] {
        let data = try await send(path: path, query: query)
        return try JSONDecoder().decode([T].self, from: data)
    }

    // MARK: - app_config helpers

    static func appConfig<T: Decodable>(_ type: T.Type, key: String) async throws -> T? {
        let data = try await send(
            path: "app_config",
            query: [
                URLQueryItem(name: "select", value: "value"),
                URLQueryItem(name: "key", value: "eq.\(key)")
            ]
        )
        let rows = try JSONDecoder().decode([SupabaseConfigRow<T>].self, from: data)
        return rows.first?.value
    }

    static func saveAppConfig<T: Encodable>(key: String, value: T) async throws {
        let payload = SupabaseConfigWrite(
            key: key,
            value: value,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        let body = try JSONEncoder().encode([payload])
        try await send(
            path: "app_config",
            query: [URLQueryItem(name: "on_conflict", value: "key")],
            method: "POST",
            body: body,
            prefer: "resolution=merge-duplicates"
        )
    }

    // MARK: - Domain calls

    static func fetchSchedule() async -> ScheduleConfig {
        do {
            if let config = try await appConfig(ScheduleConfig.self, key: "schedule") {
                return config
            }
        } catch {
            print("[schedule] fetch failed: \(error.localizedDescription)")
        }
        return .fallback
    }

    static func fetchCameras() async -> [CameraVideo] {
        do {
            let config = try await appConfig(CamerasConfig.self, key: "cameras")
            return (config?.videos ?? []).filter { !$0.id.trimmingCharacters(in: .whitespaces).isEmpty }
        } catch {
            print("[cameras] fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    static func fetchBoatLocation() async -> BoatLocation? {
        do {
            return try await appConfig(BoatLocation.self, key: "boat_location")
        } catch {
            return nil
        }
    }

    /// Toggles the crew's "hide from customers" flag without disturbing the
    /// live position or tracking state (fetch-modify-save keeps everything else).
    static func setBoatHidden(_ hidden: Bool) async throws {
        var location = (try await appConfig(BoatLocation.self, key: "boat_location"))
            ?? BoatLocation(
                latitude: 55.3338,
                longitude: -1.5803,
                accuracy: nil,
                heading: nil,
                speed: nil,
                updatedAt: ISO8601DateFormatter().string(from: Date()),
                isTracking: false,
                isHidden: nil
            )
        location.isHidden = hidden
        try await saveAppConfig(key: "boat_location", value: location)
    }

    static func fetchPlacesToEat() async -> [PlaceToEat] {
        do {
            return try await appConfig([PlaceToEat].self, key: "places_to_eat") ?? []
        } catch {
            print("[places] fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    static func savePlacesToEat(_ places: [PlaceToEat]) async throws {
        try await saveAppConfig(key: "places_to_eat", value: places)
    }

    static func saveSchedule(_ config: ScheduleConfig) async throws {
        try await saveAppConfig(key: "schedule", value: config)
    }

    static func fetchPreprintedBoarding() async -> PreprintedBoarding {
        do {
            return try await appConfig(PreprintedBoarding.self, key: "preprinted_boarding")
                ?? PreprintedBoarding(count: 0, lastScanAt: nil)
        } catch {
            return PreprintedBoarding(count: 0, lastScanAt: nil)
        }
    }

    static func savePreprintedBoarding(_ value: PreprintedBoarding) async throws {
        try await saveAppConfig(key: "preprinted_boarding", value: value)
    }

    static func fetchBookings(email: String) async -> [Booking] {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        do {
            return try await fetch(
                Booking.self,
                path: "bookings",
                query: [
                    URLQueryItem(name: "select", value: "id,customer_name,cruise_name,cruise_date,cruise_time,adults,children,customer_email,status"),
                    URLQueryItem(name: "customer_email", value: "ilike.\(trimmed)"),
                    URLQueryItem(name: "status", value: "in.(paid,boarded)"),
                    URLQueryItem(name: "order", value: "cruise_date.desc"),
                    URLQueryItem(name: "limit", value: "20")
                ]
            )
        } catch {
            print("[tickets] fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    static func fetchAllBookings(email: String) async -> [Booking] {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        do {
            return try await fetch(
                Booking.self,
                path: "bookings",
                query: [
                    URLQueryItem(name: "select", value: "id,customer_name,cruise_name,cruise_date,cruise_time,adults,children,customer_email,status"),
                    URLQueryItem(name: "customer_email", value: "ilike.\(trimmed)"),
                    URLQueryItem(name: "order", value: "cruise_date.desc"),
                    URLQueryItem(name: "limit", value: "40")
                ]
            )
        } catch {
            return []
        }
    }

    static func fetchBooking(id: String) async throws -> Booking? {
        let rows = try await fetch(
            Booking.self,
            path: "bookings",
            query: [
                URLQueryItem(name: "select", value: "id,customer_name,cruise_name,cruise_date,cruise_time,adults,children,customer_email,status"),
                URLQueryItem(name: "id", value: "eq.\(id)")
            ]
        )
        return rows.first
    }

    static func fetchBoardedBookings() async -> [Booking] {
        do {
            return try await fetch(
                Booking.self,
                path: "bookings",
                query: [
                    URLQueryItem(name: "select", value: "id,customer_name,cruise_name,cruise_date,cruise_time,adults,children,customer_email,status"),
                    URLQueryItem(name: "status", value: "eq.boarded"),
                    URLQueryItem(name: "order", value: "cruise_date.desc"),
                    URLQueryItem(name: "limit", value: "100")
                ]
            )
        } catch {
            return []
        }
    }

    static func updateBookingStatus(id: String, status: String) async throws {
        let body = try JSONEncoder().encode(BookingStatusPatch(status: status))
        try await send(
            path: "bookings",
            query: [URLQueryItem(name: "id", value: "eq.\(id)")],
            method: "PATCH",
            body: body
        )
    }

    static func resetBoardedBookings() async throws {
        let body = try JSONEncoder().encode(BookingStatusPatch(status: "paid"))
        try await send(
            path: "bookings",
            query: [URLQueryItem(name: "status", value: "eq.boarded")],
            method: "PATCH",
            body: body
        )
    }

    static func fetchGalleryPhotos() async -> [GalleryPhoto] {
        do {
            return try await fetch(
                GalleryPhoto.self,
                path: "gallery_photos",
                query: [
                    URLQueryItem(name: "select", value: "id,image_url,caption,guest_name,created_at"),
                    URLQueryItem(name: "approved", value: "eq.true"),
                    URLQueryItem(name: "order", value: "created_at.desc"),
                    URLQueryItem(name: "limit", value: "120")
                ]
            )
        } catch {
            print("[gallery] fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    static func fetchPushTokens() async -> [String] {
        do {
            let rows = try await fetch(
                PushTokenRow.self,
                path: "push_tokens",
                query: [URLQueryItem(name: "select", value: "token")]
            )
            return rows.map(\.token)
        } catch {
            return []
        }
    }

    /// Stores or refreshes a device push token so broadcasts can reach it.
    static func upsertPushToken(_ token: String, platform: String) async {
        guard isConfigured, !token.isEmpty else { return }
        do {
            let body = try JSONEncoder().encode([PushTokenUpsert(token: token, platform: platform)])
            try await send(
                path: "push_tokens",
                query: [URLQueryItem(name: "on_conflict", value: "token")],
                method: "POST",
                body: body,
                prefer: "resolution=merge-duplicates"
            )
        } catch {
            print("[push] token save failed: \(error.localizedDescription)")
        }
    }
}
