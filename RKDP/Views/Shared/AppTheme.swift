import SwiftUI

enum AppTheme {
    // Puzzle Party palette: soft logo-inspired party blocks on a bright friendly base.
    static let iconBlue         = Color(hex: "5BCBE3")
    static let royalBlue        = Color(hex: "46B8D6")
    static let iconPurple       = Color(hex: "B78BE9")
    static let crownGold        = Color(hex: "F8D77B")
    static let hotPink          = Color(hex: "F24793")
    static let teal             = Color(hex: "59C9DD")
    static let lime             = Color(hex: "B7DE82")
    static let coral            = Color(hex: "F76378")
    static let cream            = Color(hex: "FFF6E7")
    static let plum             = Color(hex: "372A3C")
    static let success          = Color(hex: "AEE67B")
    static let warning          = crownGold
    static let danger           = coral

    // Background: soft pastel party base inspired by the Puzzle Party logo.
    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "FFF8EC"), Color(hex: "FCEBFA"), Color(hex: "E8F8F9")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static var arenaBackground: some View { ArenaBackgroundView() }

    // Brand: logo hot pink into coral with a candy-pop finish.
    static let brandGradient = LinearGradient(
        colors: [hotPink, coral],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let cardBackground   = Color.white.opacity(0.76)
    static let cardBorder       = hotPink.opacity(0.24)
    static let textPrimary      = plum
    static let textSecondary    = plum.opacity(0.68)
    static let textOnColor      = Color.white
    static let softShadow       = plum.opacity(0.12)
    static let accent           = hotPink
    static let accentBright     = hotPink

    // Each mode keeps its identity, tuned into the Puzzle Party logo palette.
    static func modeGradient(_ mode: GameMode) -> LinearGradient {
        switch mode {
        case .sudoku:
            return LinearGradient(colors: [Color(hex: "A8EDF4"), Color.white],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .minesweeper:
            return LinearGradient(colors: [Color(hex: "FF8DA0"), hotPink, crownGold],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .colorLink:
            return LinearGradient(colors: [teal, hotPink, lime],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .gridlock:
            return LinearGradient(colors: [crownGold, teal],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .anagram:
            return LinearGradient(colors: [hotPink, Color(hex: "D96CE6")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .wordHunt:
            return LinearGradient(colors: [teal, Color(hex: "87DDF4")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .wordle:
            return LinearGradient(colors: [lime, teal],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .hangman:
            return LinearGradient(colors: [coral, crownGold, hotPink],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    static func modeShadow(_ mode: GameMode) -> Color {
        switch mode {
        case .sudoku:      return iconBlue.opacity(0.62)
        case .minesweeper: return hotPink.opacity(0.62)
        case .colorLink:   return teal.opacity(0.62)
        case .gridlock:    return crownGold.opacity(0.62)
        case .anagram:     return hotPink.opacity(0.62)
        case .wordHunt:    return royalBlue.opacity(0.62)
        case .wordle:      return teal.opacity(0.62)
        case .hangman:     return coral.opacity(0.62)
        }
    }

    // Per-mode accent colour (flat) for text/badges.
    static func modeAccent(_ mode: GameMode) -> Color {
        switch mode {
        case .sudoku:      return iconBlue
        case .minesweeper: return hotPink
        case .colorLink:   return teal
        case .gridlock:    return crownGold
        case .anagram:     return hotPink
        case .wordHunt:    return royalBlue
        case .wordle:      return lime
        case .hangman:     return coral
        }
    }
}

private struct ArenaBackgroundView: View {
    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
            RadialGradient(
                colors: [AppTheme.teal.opacity(0.30), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 430
            )
            RadialGradient(
                colors: [AppTheme.hotPink.opacity(0.22), .clear],
                center: .bottomTrailing,
                startRadius: 60,
                endRadius: 540
            )
            RadialGradient(
                colors: [AppTheme.lime.opacity(0.32), .clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 460
            )
            RadialGradient(
                colors: [AppTheme.crownGold.opacity(0.26), .clear],
                center: .bottomLeading,
                startRadius: 30,
                endRadius: 430
            )
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
