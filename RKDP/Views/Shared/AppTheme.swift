import SwiftUI

enum AppTheme {
    // Background: deep warm navy — feels rich but lets bright colours pop
    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "0F0E2A"), Color(hex: "1A1040"), Color(hex: "0D1B3E")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // Brand: coral-orange to hot pink — warm, energetic, fun
    static let brandGradient = LinearGradient(
        colors: [Color(hex: "FF6B35"), Color(hex: "F72585")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let cardBackground   = Color.white.opacity(0.09)
    static let cardBorder       = Color.white.opacity(0.14)
    static let textPrimary      = Color.white
    static let textSecondary    = Color.white.opacity(0.65)
    static let accent           = Color(hex: "F72585")   // hot pink
    static let accentBright     = Color(hex: "FF9F1C")   // amber/orange

    // Each mode gets its own bold saturated gradient
    static func modeGradient(_ mode: GameMode) -> LinearGradient {
        switch mode {
        case .sudoku:
            return LinearGradient(colors: [Color(hex: "3A86FF"), Color(hex: "00CFFD")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .minesweeper:
            return LinearGradient(colors: [Color(hex: "FF6B35"), Color(hex: "FF9F1C")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .kakuro:
            return LinearGradient(colors: [Color(hex: "06D6A0"), Color(hex: "1B998B")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .kenken:
            return LinearGradient(colors: [Color(hex: "FFBE0B"), Color(hex: "FB5607")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .anagram:
            return LinearGradient(colors: [Color(hex: "F72585"), Color(hex: "7209B7")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .wordHunt:
            return LinearGradient(colors: [Color(hex: "4CC9F0"), Color(hex: "4361EE")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .wordle:
            return LinearGradient(colors: [Color(hex: "538D4E"), Color(hex: "6AAB9C")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    static func modeShadow(_ mode: GameMode) -> Color {
        switch mode {
        case .sudoku:      return Color(hex: "3A86FF").opacity(0.5)
        case .minesweeper: return Color(hex: "FF6B35").opacity(0.5)
        case .kakuro:      return Color(hex: "06D6A0").opacity(0.5)
        case .kenken:      return Color(hex: "FFBE0B").opacity(0.5)
        case .anagram:     return Color(hex: "F72585").opacity(0.5)
        case .wordHunt:    return Color(hex: "4CC9F0").opacity(0.5)
        case .wordle:      return Color(hex: "538D4E").opacity(0.5)
        }
    }

    // Per-mode accent colour (flat) for text/badges
    static func modeAccent(_ mode: GameMode) -> Color {
        switch mode {
        case .sudoku:      return Color(hex: "4CC9F0")
        case .minesweeper: return Color(hex: "FF9F1C")
        case .kakuro:      return Color(hex: "06D6A0")
        case .kenken:      return Color(hex: "FFBE0B")
        case .anagram:     return Color(hex: "F72585")
        case .wordHunt:    return Color(hex: "4361EE")
        case .wordle:      return Color(hex: "538D4E")
        }
    }
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
