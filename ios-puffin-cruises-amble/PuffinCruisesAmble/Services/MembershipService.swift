import Foundation
import RevenueCat

/// RevenueCat-backed annual membership ("membership" entitlement).
/// Mirrors the Expo app's flow: buy the first package in the current offering,
/// then sync the QR member pass to the backend with the real expiry date.
enum MembershipService {
    static let entitlementID = "membership"

    // Same live iOS key the Expo app uses; an injected env value wins when present.
    private static let liveAPIKey = "appl_otLFzRBmUwDxcahJfwKDGkvvLxm"
    private static let memberIDKey = "puffin_member_id"

    private static var isConfigured = false

    private static var apiKey: String {
        let injected = Config.allValues["EXPO_PUBLIC_REVENUECAT_IOS_API_KEY"] ?? ""
        return injected.isEmpty ? liveAPIKey : injected
    }

    /// Stable member id shared by purchases and the QR pass.
    static func memberID() -> String {
        if let existing = UserDefaults.standard.string(forKey: memberIDKey) { return existing }
        let next = "mem_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8))"
        UserDefaults.standard.set(next, forKey: memberIDKey)
        return next
    }

    static func configureIfNeeded() {
        guard !isConfigured else { return }
        Purchases.configure(withAPIKey: apiKey, appUserID: memberID())
        isConfigured = true
    }

    /// First package of the current offering (annual membership).
    static func loadOfferingPackage() async -> Package? {
        configureIfNeeded()
        let offerings = try? await Purchases.shared.offerings()
        return offerings?.current?.availablePackages.first
    }

    static func isMembershipActive() async -> Bool {
        await customerInfo()?.entitlements.active[entitlementID] != nil
    }

    static func customerInfo() async -> CustomerInfo? {
        configureIfNeeded()
        return try? await Purchases.shared.customerInfo()
    }

    static func purchase(_ package: Package) async throws -> CustomerInfo {
        configureIfNeeded()
        let result = try await Purchases.shared.purchase(package: package)
        return result.customerInfo
    }

    static func restorePurchases() async throws -> CustomerInfo {
        configureIfNeeded()
        return try await Purchases.shared.restorePurchases()
    }

    /// ISO-8601 expiry of the active entitlement, falling back to one year out.
    static func activeExpirationISO(from info: CustomerInfo?) -> String {
        let formatter = ISO8601DateFormatter()
        if let expiry = info?.entitlements.active[entitlementID]?.expirationDate {
            return formatter.string(from: expiry)
        }
        return formatter.string(from: Date().addingTimeInterval(365 * 24 * 60 * 60))
    }
}
