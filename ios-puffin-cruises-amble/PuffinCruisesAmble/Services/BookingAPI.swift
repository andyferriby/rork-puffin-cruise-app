import Foundation

nonisolated struct CheckoutRequest: Encodable {
    let cruiseId: String
    let cruiseName: String
    let date: String
    let time: String
    let adults: Int
    let children: Int
    let customerName: String
    let customerEmail: String
    let customerPhone: String
}

nonisolated struct CheckoutResponse: Decodable {
    let url: String
    let bookingId: String
}

nonisolated enum BookingAPIError: LocalizedError {
    case notConfigured
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "The booking service is not configured."
        case let .failed(message): return message
        }
    }
}

nonisolated struct MembershipRedeemBody: Encodable {
    let memberId: String
}

nonisolated struct MembershipSyncBody: Encodable {
    let memberId: String
    let email: String
    let active: Bool
    let expiresAt: String
}

nonisolated struct StoreCredentials: Decodable {
    let storeUrl: String?
    let consumerKey: String?
    let consumerSecret: String?
}

nonisolated struct ShopProxyBody: Encodable {
    let storeUrl: String
    let consumerKey: String
    let consumerSecret: String
}

nonisolated struct ShopProxyResponse: Decodable {
    let products: [ShopProduct]?
}

nonisolated struct PushMessage: Encodable {
    let to: String
    let title: String
    let body: String
    let sound: String
}

/// Talks to the same Cloudflare functions backend the Expo app uses.
/// MainActor-isolated (project default) so it can read `Config`.
enum BookingAPI {
    private static var base: String {
        Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func walletPassURL(bookingId: String) -> URL? {
        guard !base.isEmpty,
              let encoded = bookingId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        return URL(string: "\(base)/wallet/pass?bookingId=\(encoded)")
    }

    static func createCheckout(_ payload: CheckoutRequest) async throws -> CheckoutResponse {
        guard !base.isEmpty, let url = URL(string: "\(base)/checkout") else {
            throw BookingAPIError.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw BookingAPIError.failed(body)
        }
        return try JSONDecoder().decode(CheckoutResponse.self, from: data)
    }

    static func redeemMembership(memberId: String) async throws -> MembershipPass {
        guard !base.isEmpty, let url = URL(string: "\(base)/membership/redeem") else {
            throw BookingAPIError.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(MembershipRedeemBody(memberId: memberId))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BookingAPIError.failed(String(data: data, encoding: .utf8) ?? "Redeem failed")
        }
        return try JSONDecoder().decode(MembershipPass.self, from: data)
    }

    static func syncMembership(memberId: String, email: String, active: Bool, expiresAt: String) async throws -> MembershipPass {
        guard !base.isEmpty, let url = URL(string: "\(base)/membership/sync") else {
            throw BookingAPIError.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            MembershipSyncBody(memberId: memberId, email: email.lowercased(), active: active, expiresAt: expiresAt)
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BookingAPIError.failed(String(data: data, encoding: .utf8) ?? "Sync failed")
        }
        return try JSONDecoder().decode(MembershipPass.self, from: data)
    }

    static func fetchShopProducts() async -> [ShopProduct] {
        guard !base.isEmpty, let url = URL(string: "\(base)/woocommerce/products") else { return [] }
        do {
            guard let config = try await SupabaseService.appConfig(StoreCredentials.self, key: "woocommerce"),
                  let storeUrl = config.storeUrl?.trimmingCharacters(in: .whitespaces),
                  !storeUrl.isEmpty
            else { return [] }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(
                ShopProxyBody(
                    storeUrl: storeUrl,
                    consumerKey: config.consumerKey ?? "",
                    consumerSecret: config.consumerSecret ?? ""
                )
            )
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(ShopProxyResponse.self, from: data).products ?? []
        } catch {
            print("[shop] fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Broadcasts a push to every registered device: Expo tokens go via Expo's
    /// push API; native APNs tokens go through the backend's .p8 signing relay.
    static func sendBroadcastPush(title: String, body: String) async throws -> Int {
        let tokens = await SupabaseService.fetchPushTokens()
        let expoTokens = tokens.filter { $0.hasPrefix("Expo") }
        var delivered = 0

        if !expoTokens.isEmpty {
            guard let url = URL(string: "https://exp.host/--/api/v2/push/send") else { return 0 }
            for chunk in stride(from: 0, to: expoTokens.count, by: 90).map({ Array(expoTokens[$0..<min($0 + 90, expoTokens.count)]) }) {
                let messages = chunk.map { PushMessage(to: $0, title: title, body: body, sound: "default") }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(messages)
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    throw BookingAPIError.failed("Push service returned \(http.statusCode)")
                }
            }
            delivered += expoTokens.count
        }

        delivered += await sendApnsBroadcast(title: title, body: body)
        return delivered
    }

    /// Native APNs devices are sent via the Cloudflare function, which signs
    /// requests with the team's APNs key server-side.
    private static func sendApnsBroadcast(title: String, body: String) async -> Int {
        guard let url = URL(string: "\(base)/push/apns") else { return 0 }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["title": title, "body": body])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                print("[push] apns relay rejected")
                return 0
            }
            struct ApnsResult: Decodable { let sent: Int }
            return (try? JSONDecoder().decode(ApnsResult.self, from: data))?.sent ?? 0
        } catch {
            print("[push] apns relay error: \(error.localizedDescription)")
            return 0
        }
    }
}
