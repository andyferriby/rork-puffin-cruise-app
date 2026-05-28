import Foundation

/// Local persistence for booking IDs the user has created on this device.
@MainActor
final class BookingsStore {
    static let shared = BookingsStore()
    private let key = "my_booking_ids"
    private let emailKey = "my_email"

    private init() {}

    func savedIds() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    func add(_ id: String) {
        var ids = savedIds()
        if !ids.contains(id) {
            ids.insert(id, at: 0)
            UserDefaults.standard.set(ids, forKey: key)
        }
    }

    func remove(_ id: String) {
        var ids = savedIds()
        ids.removeAll { $0 == id }
        UserDefaults.standard.set(ids, forKey: key)
    }

    var savedEmail: String? {
        get { UserDefaults.standard.string(forKey: emailKey) }
        set { UserDefaults.standard.set(newValue, forKey: emailKey) }
    }
}
