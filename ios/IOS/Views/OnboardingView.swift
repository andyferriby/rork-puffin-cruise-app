import SwiftUI

struct OnboardingSlide: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    let subtitle: String
    let color: Color
}

private let slides: [OnboardingSlide] = [
    OnboardingSlide(
        emoji: "⛴️",
        title: "Welcome to\nPuffin Cruises",
        subtitle: "Discover the wild beauty of Coquet Island with Dave Gray's family-run boat tours from Amble Harbour.",
        color: Theme.sea
    ),
    OnboardingSlide(
        emoji: "📅",
        title: "Book Your\nAdventure",
        subtitle: "Choose from puffin-spotting cruises, seal-watching tours, or sunset sails. Pick your date, time, and number of passengers — then pay securely with card.",
        color: Theme.wave
    ),
    OnboardingSlide(
        emoji: "🦭",
        title: "Meet the\nWildlife",
        subtitle: "Coquet Island is home to 40,000+ puffins, grey seals, Arctic terns, and more. Our wildlife guide helps you identify every species you'll see.",
        color: Theme.coral
    ),
    OnboardingSlide(
        emoji: "🎟️",
        title: "Your Tickets\n& Rewards",
        subtitle: "Boarding passes live in the app — scan the QR code at the pier. Earn loyalty points on every trip and unlock perks as you sail more.",
        color: Theme.puffin
    ),
    OnboardingSlide(
        emoji: "⚓",
        title: "Ready to\nSet Sail?",
        subtitle: "Check the arrival guide before you come, share the app with friends for rewards, and let's get you on the water.",
        color: Theme.deep
    ),
]

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()

            VStack(spacing: 0) {
                skipButton
                slideCarousel
                pageIndicators
                actionButton
            }
        }
    }

    // MARK: - Skip

    private var skipButton: some View {
        HStack {
            Spacer()
            if currentPage < slides.count - 1 {
                Button("Skip") {
                    finish()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.foam.opacity(0.7))
                .padding(.trailing, 24)
                .padding(.top, 16)
            }
        }
    }

    // MARK: - Carousel

    private var slideCarousel: some View {
        TabView(selection: $currentPage) {
            ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
                slideView(slide, index: index)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.spring(duration: 0.5), value: currentPage)
    }

    private func slideView(_ slide: OnboardingSlide, index: Int) -> some View {
        VStack(spacing: 0) {
            Spacer()

            emojiCircle(slide)

            Text(slide.title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.white)
                .multilineTextAlignment(.center)
                .padding(.top, 40)
                .padding(.horizontal, 32)

            Text(slide.subtitle)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundStyle(Theme.foam.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.top, 16)
                .padding(.horizontal, 36)

            Spacer()
            Spacer()
        }
    }

    private func emojiCircle(_ slide: OnboardingSlide) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [slide.color, slide.color.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 140, height: 140)

            Circle()
                .strokeBorder(slide.color.opacity(0.5), lineWidth: 3)
                .frame(width: 168, height: 168)

            Text(slide.emoji)
                .font(.system(size: 64))
        }
    }

    // MARK: - Page Dots

    private var pageIndicators: some View {
        HStack(spacing: 10) {
            ForEach(0..<slides.count, id: \.self) { index in
                Capsule()
                    .fill(currentPage == index ? Theme.white : Theme.white.opacity(0.3))
                    .frame(width: currentPage == index ? 28 : 8, height: 8)
                    .animation(.spring(duration: 0.4), value: currentPage)
            }
        }
        .padding(.bottom, 32)
    }

    // MARK: - Button

    private var actionButton: some View {
        Button {
            if currentPage < slides.count - 1 {
                withAnimation {
                    currentPage += 1
                }
            } else {
                finish()
            }
        } label: {
            HStack(spacing: 8) {
                Text(currentPage < slides.count - 1 ? "Next" : "Get Started")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))

                if currentPage < slides.count - 1 {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Theme.white)
            .clipShape(.rect(cornerRadius: 16))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 50)
    }

    // MARK: - Finish

    private func finish() {
        withAnimation(.spring(duration: 0.5)) {
            hasSeenOnboarding = true
        }
    }
}

#Preview {
    OnboardingView()
}
