import SwiftUI

enum AppTheme {
    // Brand gradients
    static let brandGradient = LinearGradient(
        colors: [Color(hex: "3B1FA8"), Color(hex: "7B2FBE"), Color(hex: "A855F7")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "0D0820"), Color(hex: "1A0A3B"), Color(hex: "220D4A")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let cardBackground = Color.white.opacity(0.08)
    static let cardBorder     = Color.white.opacity(0.13)
    static let textPrimary    = Color.white
    static let textSecondary  = Color.white.opacity(0.65)
    static let accent         = Color(hex: "A855F7")   // violet
    static let accentBright   = Color(hex: "C084FC")   // light purple

    // All game modes share the brand accent — differentiated only by icon
    static func modeGradient(_ mode: GameMode) -> LinearGradient {
        switch mode {
        case .sudoku:
            return LinearGradient(colors: [Color(hex: "4F46E5"), Color(hex: "818CF8")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .minesweeper:
            return LinearGradient(colors: [Color(hex: "7C3AED"), Color(hex: "C084FC")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .kakuro:
            return LinearGradient(colors: [Color(hex: "6D28D9"), Color(hex: "A78BFA")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .kenken:
            return LinearGradient(colors: [Color(hex: "8B5CF6"), Color(hex: "DDD6FE")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .anagram:
            return LinearGradient(colors: [Color(hex: "9333EA"), Color(hex: "F0ABFC")], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    static func modeShadow(_ mode: GameMode) -> Color { Color(hex: "7C3AED").opacity(0.5) }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8)  & 0xFF) / 255
            b = Double( int        & 0xFF) / 255
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}
