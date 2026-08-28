import CoreLocation
import SwiftUI

/// The Talking Harbour — four narrated stories by George, bundled offline.
/// Guests can tap any story to listen, or start a harbour walk and each story
/// plays itself, with a haptic, as they pass its exact spot (80 m trigger).
struct TalkingHarbourView: View {
    @State private var audio = StoryAudioService.shared
    @State private var walk = StoryWalkManager()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                introCard
                walkSection
                VStack(spacing: 12) {
                    ForEach(HarbourStories.all) { story in
                        storyCard(story)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Theme.bg)
        .navigationTitle("Talking Harbour")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            // Keep audio playing if the user navigates within the app, but
            // end the walk if they back out mid-stroll.
            if walk.isWalking { walk.endWalk() }
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.puffin)
                Text("THE TALKING HARBOUR")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(Theme.puffin)
            }
            Text("Four stories told as you walk")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Theme.text)
            Text("Narrated by George, a warm British storyteller, and bundled inside the app so they play offline any time. Start a harbour walk and each story plays itself — with a haptic — as you pass its exact spot.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textMuted)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .puffinCard(radius: 18, fill: Theme.foam)
    }

    // MARK: - Walk mode

    @ViewBuilder
    private var walkSection: some View {
        if walk.isWalking {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Walk in progress")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Text("\(walk.visitedCount) of \(HarbourStories.all.count) heard")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.sea)
                }

                if let next = walk.nextStory, let distance = walk.distanceToNextStory {
                    Text(nextStoryText(next, distance: distance))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textMuted)
                } else if walk.visitedCount >= HarbourStories.all.count {
                    Text("You've heard all four stories — brilliant walking with you.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.sea)
                }

                Button {
                    walk.endWalk()
                } label: {
                    Text("End walk")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.coral)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.coral.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 12))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .puffinCard(radius: 18, fill: .white)
        } else {
            Button {
                walk.startWalk()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 18, weight: .bold))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Start Harbour Walk")
                            .font(.system(size: 15, weight: .bold))
                        Text("Stories play themselves as you pass")
                            .font(.system(size: 12, weight: .medium))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(16)
                .background(
                    LinearGradient(colors: [Theme.deep, Theme.sea], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(.rect(cornerRadius: 18))
            }
        }

        if walk.locationDenied {
            Label("Location is off for this app — allow it in Settings to use the walk.", systemImage: "location.slash")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.coral)
        }
    }

    private func nextStoryText(_ story: HarbourStory, distance: CLLocationDistance) -> String {
        let metres = Int(distance.rounded())
        let when = metres <= 80 ? "now" : metres < 1000 ? "in \(metres) m" : String(format: "in %.1f km", distance / 1000)
        return "Next story: \(story.title) — \(when)."
    }

    // MARK: - Story cards

    private func storyCard(_ story: HarbourStory) -> some View {
        let playing = audio.isStoryPlaying(story)
        return Button {
            audio.toggle(story)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: playing ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(playing ? Theme.coral : Theme.sea)
                    .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(story.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.text)
                        if walk.isWalking && walk.visitedStoryIDs.contains(story.id) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.green)
                        }
                    }
                    Text(story.blurb)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textMuted)
                        .multilineTextAlignment(.leading)
                    if playing {
                        Text("Now playing · George")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.coral)
                    } else if audio.hasPlayed(story) {
                        Text("Played")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.green)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .puffinCard(radius: 18, fill: playing ? Theme.coral.opacity(0.06) : .white)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
