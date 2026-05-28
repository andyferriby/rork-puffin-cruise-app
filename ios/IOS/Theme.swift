import SwiftUI

enum Theme {
    static let ink = Color(hex: "06121F")
    static let deep = Color(hex: "0B2A4A")
    static let sea = Color(hex: "0E4D7A")
    static let wave = Color(hex: "2B86C5")
    static let foam = Color(hex: "E8F2F8")
    static let sand = Color(hex: "F4E3C1")
    static let sandDeep = Color(hex: "D9B976")
    static let coral = Color(hex: "FF6B57")
    static let puffin = Color(hex: "FF8A3D")
    static let white = Color.white
    static let text = Color(hex: "0A1622")
    static let textMuted = Color(hex: "5B6B7A")
    static let border = Color(hex: "0B2A4A").opacity(0.08)
    static let card = Color.white
    static let bg = Color(hex: "F6F9FB")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
