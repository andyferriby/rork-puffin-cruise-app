import SwiftUI

enum WatchTheme {
    static let deep = Color(red: 0.04, green: 0.15, blue: 0.29)
    static let gold = Color(red: 0.95, green: 0.72, blue: 0.25)
    static let mint = Color(red: 0.35, green: 0.8, blue: 0.7)
}

/// Shared deep-sea page background used by every watch page.
struct WatchPageBackground: View {
    var body: some View {
        ZStack {
            WatchTheme.deep.ignoresSafeArea()
            LinearGradient(
                colors: [Color.white.opacity(0.06), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

/// Section header at the top of each watch page.
struct WatchPageHeader: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(WatchTheme.gold)
            Text(title)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
    }
}

/// Small empty/error status card.
struct WatchStatusCard: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(WatchTheme.gold)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .watchCard()
    }
}

extension View {
    /// Standard translucent harbour card.
    func watchCard() -> some View {
        self
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07)))
    }
}
