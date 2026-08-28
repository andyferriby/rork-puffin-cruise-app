import AVFoundation
import UIKit

/// Plays the bundled Talking Harbour narrations. Uses the `.playback` audio
/// session category so stories keep playing with the screen off (background
/// audio mode is enabled in the app's build settings).
@MainActor
@Observable
final class StoryAudioService {
    static let shared = StoryAudioService()

    private var player: AVAudioPlayer?
    private(set) var currentStory: HarbourStory?
    private(set) var isPlaying = false
    private(set) var playedStoryIDs: Set<String> = []

    func isStoryPlaying(_ story: HarbourStory) -> Bool {
        currentStory?.id == story.id && isPlaying
    }

    func hasPlayed(_ story: HarbourStory) -> Bool {
        playedStoryIDs.contains(story.id)
    }

    func markPlayed(_ story: HarbourStory) {
        playedStoryIDs.insert(story.id)
    }

    /// Toggles playback for a story (tap-to-listen).
    func toggle(_ story: HarbourStory) {
        if currentStory?.id == story.id {
            if isPlaying {
                pause()
            } else {
                resume()
            }
            return
        }
        play(story)
    }

    func play(_ story: HarbourStory) {
        guard let url = Bundle.main.url(forResource: story.resource, withExtension: "mp3") else {
            print("[stories] missing audio resource: \(story.resource)")
            return
        }
        configureAudioSession()
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = PlayerDelegateBridge.shared
            newPlayer.prepareToPlay()
            newPlayer.play()
            player?.stop()
            player = newPlayer
            currentStory = story
            isPlaying = true
            playedStoryIDs.insert(story.id)
        } catch {
            print("[stories] playback failed: \(error.localizedDescription)")
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func resume() {
        configureAudioSession()
        player?.play()
        isPlaying = true
    }

    func stop() {
        player?.stop()
        player = nil
        currentStory = nil
        isPlaying = false
    }

    /// Called by the delegate bridge when playback finishes naturally.
    func finishPlayback() {
        isPlaying = false
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
        } catch {
            print("[stories] audio session failed: \(error.localizedDescription)")
        }
    }
}

/// Routes AVAudioPlayer delegate callbacks back to the main-actor service.
final class PlayerDelegateBridge: NSObject, AVAudioPlayerDelegate {
    static let shared = PlayerDelegateBridge()

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            StoryAudioService.shared.finishPlayback()
        }
    }
}
