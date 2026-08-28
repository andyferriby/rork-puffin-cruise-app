import SwiftUI

private struct OnboardingSlide: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    let subtitle: String
    let colors: [Color]
}

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @State private var page = 0

    private let slides: [OnboardingSlide] = [
        OnboardingSlide(
            emoji: "⛴️",
            title: "Welcome to\nPuffin Cruises",
            subtitle: "Book family-run wildlife adventures from Amble Harbour to Coquet Island.",
            colors: [Theme.deep, Theme.sea]
        ),
        OnboardingSlide(
            emoji: "📅",
            title: "Book Your\nAdventure",
            subtitle: "Choose your cruise, sailing time, passengers and pay securely by card.",
            colors: [Theme.sea, Theme.wave]
        ),
        OnboardingSlide(
            emoji: "🦭",
            title: "Meet the\nWildlife",
            subtitle: "Use the wildlife guide to spot puffins, seals, Arctic terns and island birds.",
            colors: [Theme.coral, Theme.puffin]
        ),
        OnboardingSlide(
            emoji: "📍",
            title: "Track the\nBoat Live",
            subtitle: "Follow the cruise on the interactive map when crew share live position updates from the water.",
            colors: [Theme.wave, Theme.deep]
        ),
        OnboardingSlide(
            emoji: "🎟️",
            title: "Tickets &\nRewards",
            subtitle: "Keep boarding passes in the app and earn Puffin Club perks as you sail.",
            colors: [Theme.puffin, Theme.sandDeep]
        ),
        OnboardingSlide(
            emoji: "⚓",
            title: "Ready to\nSet Sail?",
            subtitle: "Check the arrival guide before you come and refer friends for rewards.",
            colors: [Theme.ink, Theme.deep]
        )
    ]

    private var isLast: Bool { page == slides.count - 1 }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.ink, Theme.deep], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if !isLast {
                        Button("Skip") { finish() }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
                .padding(.horizontal, 24)
                .frame(height: 30)

                TabView(selection: $page) {
                    ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
                        VStack(spacing: 0) {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: slide.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 166, height: 166)
                                    .overlay { Circle().stroke(.white.opacity(0.22), lineWidth: 3) }
                                Text(slide.emoji).font(.system(size: 66))
                            }
                            Text(slide.title)
                                .font(.system(size: 34, weight: .black))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(.top, 42)
                            Text(slide.subtitle)
                                .font(.system(size: 17))
                                .foregroundStyle(.white.opacity(0.78))
                                .multilineTextAlignment(.center)
                                .lineSpacing(5)
                                .padding(.top, 18)
                            Spacer()
                        }
                        .padding(.horizontal, 34)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 9) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        Capsule()
                            .fill(page == index ? .white : .white.opacity(0.32))
                            .frame(width: page == index ? 30 : 8, height: 8)
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
                    }
                }
                .padding(.bottom, 28)

                Button {
                    if isLast {
                        finish()
                    } else {
                        withAnimation { page = min(page + 1, slides.count - 1) }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(isLast ? "Get Started" : "Next")
                            .font(.system(size: 18, weight: .heavy))
                        if !isLast {
                            Image(systemName: "arrow.right").font(.system(size: 16, weight: .bold))
                        }
                    }
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white)
                    .clipShape(.rect(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }

    private func finish() {
        withAnimation { settings.hasSeenOnboarding = true }
    }
}
