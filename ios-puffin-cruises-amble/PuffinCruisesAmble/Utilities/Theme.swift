import SwiftUI

/// Colour palette mirrored from the Puffin Cruises design system.
enum Theme {
    static let ink = Color(hex: 0x06121F)
    static let deep = Color(hex: 0x0B2A4A)
    static let sea = Color(hex: 0x0E4D7A)
    static let wave = Color(hex: 0x2B86C5)
    static let foam = Color(hex: 0xE8F2F8)
    static let sand = Color(hex: 0xF4E3C1)
    static let sandDeep = Color(hex: 0xD9B976)
    static let coral = Color(hex: 0xFF6B57)
    static let puffin = Color(hex: 0xFF8A3D)
    static let text = Color(hex: 0x0A1622)
    static let textMuted = Color(hex: 0x5B6B7A)
    static let border = Color(hex: 0x0B2A4A).opacity(0.08)
    static let card = Color.white
    static let bg = Color(hex: 0xF6F9FB)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Rounded card container matching the RN `card` style.
struct CardBackground: ViewModifier {
    var radius: CGFloat = 20
    var fill: Color = Theme.card

    func body(content: Content) -> some View {
        content
            .background(fill)
            .clipShape(.rect(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Theme.border, lineWidth: 1)
            }
    }
}

extension View {
    func puffinCard(radius: CGFloat = 20, fill: Color = Theme.card) -> some View {
        modifier(CardBackground(radius: radius, fill: fill))
    }
}

enum DateFormat {
    /// "Monday, 4 August"
    static func longDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "EEEE, d MMMM"
        return f.string(from: date)
    }

    /// "Mon, 4 Aug"
    static func shortDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "EEE, d MMM"
        return f.string(from: date)
    }

    /// "04/08/2026"
    static func numeric(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateStyle = .short
        return f.string(from: date)
    }

    static func parseISODate(_ value: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        if let date = f.date(from: value) { return date }
        return ISO8601DateFormatter().date(from: value)
    }
}
