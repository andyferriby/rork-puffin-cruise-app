import CoreLocation
import UIKit

/// Runs the Talking Harbour walk: follows the guest's location and plays each
/// story — with a haptic — the first time they pass within 80 m of its spot.
/// Each story fires at most once per walk.
@MainActor
@Observable
final class StoryWalkManager: NSObject, CLLocationManagerDelegate {
    static let triggerDistance: CLLocationDistance = 80

    private let locationManager = CLLocationManager()
    private var latestLocation: CLLocation?

    private(set) var isWalking = false
    private(set) var visitedStoryIDs: Set<String> = []
    private(set) var lastTriggeredStory: HarbourStory?
    private(set) var locationDenied = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 15
    }

    /// Next story the guest hasn't heard yet, nearest to their position.
    var nextStory: HarbourStory? {
        let remaining = HarbourStories.all.filter { !visitedStoryIDs.contains($0.id) }
        guard let location = latestLocation else { return remaining.first }
        return remaining.min {
            location.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))
                < location.distance(from: CLLocation(latitude: $1.latitude, longitude: $1.longitude))
        }
    }

    var distanceToNextStory: CLLocationDistance? {
        guard let story = nextStory, let location = latestLocation else { return nil }
        return location.distance(from: CLLocation(latitude: story.latitude, longitude: story.longitude))
    }

    var visitedCount: Int { visitedStoryIDs.count }

    func startWalk() {
        visitedStoryIDs = []
        lastTriggeredStory = nil
        locationDenied = false
        isWalking = true
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            locationDenied = true
            isWalking = false
        default:
            locationManager.startUpdatingLocation()
        }
    }

    func endWalk() {
        isWalking = false
        locationManager.stopUpdatingLocation()
        latestLocation = nil
    }

    private func evaluate(location: CLLocation) {
        latestLocation = location
        guard isWalking else { return }
        for story in HarbourStories.all where !visitedStoryIDs.contains(story.id) {
            let spot = CLLocation(latitude: story.latitude, longitude: story.longitude)
            if location.distance(from: spot) <= Self.triggerDistance {
                visitedStoryIDs.insert(story.id)
                lastTriggeredStory = story
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                StoryAudioService.shared.play(story)
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.evaluate(location: location)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .denied, .restricted:
                if self.isWalking {
                    self.locationDenied = true
                    self.isWalking = false
                    self.locationManager.stopUpdatingLocation()
                }
            case .authorizedWhenInUse, .authorizedAlways:
                if self.isWalking {
                    self.locationManager.startUpdatingLocation()
                }
            default:
                break
            }
        }
    }
}
