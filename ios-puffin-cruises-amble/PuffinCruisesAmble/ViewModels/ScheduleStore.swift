import Observation
import SwiftUI

/// Shared schedule + config state, mirroring the Expo app's react-query `schedule` cache.
@Observable
final class ScheduleStore {
    var config: ScheduleConfig = .fallback
    var isLoading = false
    var hasLoaded = false

    var cruises: [Cruise] { config.cruises }
    var days: [DaySchedule] { config.days }
    var today: DaySchedule? { config.days.first }

    func cruise(id: String) -> Cruise? {
        config.cruises.first { $0.id == id }
    }

    func load(force: Bool = false) async {
        if hasLoaded && !force { return }
        isLoading = true
        let next = await SupabaseService.fetchSchedule()
        config = next
        isLoading = false
        hasLoaded = true
    }
}

/// Tracks whether onboarding has been shown, matching `@puffin_has_seen_onboarding`.
@Observable
final class AppSettings {
    private let onboardingKey = "puffin_has_seen_onboarding"

    var hasSeenOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasSeenOnboarding, forKey: onboardingKey) }
    }

    var showAdmin = false

    init() {
        hasSeenOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
    }
}
