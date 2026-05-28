import Foundation

@MainActor
final class APIService: Sendable {
    static let shared = APIService()

    private let baseURL: String

    private init() {
        baseURL = Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL
    }

    func createCheckout(_ body: CreateCheckoutBody) async throws -> CreateCheckoutResponse {
        let url = URL(string: "\(baseURL)/checkout")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "APIService", code: (response as? HTTPURLResponse)?.statusCode ?? 500,
                          userInfo: [NSLocalizedDescriptionKey: "Checkout failed: \(text)"])
        }
        return try JSONDecoder().decode(CreateCheckoutResponse.self, from: data)
    }

    func sendNotification(title: String, body: String) async throws {
        let url = URL(string: "\(baseURL)/notify")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = ["title": title, "body": body]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "APIService", code: (response as? HTTPURLResponse)?.statusCode ?? 500,
                          userInfo: [NSLocalizedDescriptionKey: "Notify failed: \(text)"])
        }
    }
}
