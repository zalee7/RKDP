import SwiftUI

enum AppTheme {
    // Puzzle Party palette: dark candy base with logo-inspired party blocks.
    static let iconBlue         = Color(hex: "5BCBE3")
    static let royalBlue        = Color(hex: "46B8D6")
    static let iconPurple       = Color(hex: "8A4D84")
    static let crownGold        = Color(hex: "F8D77B")
    static let hotPink          = Color(hex: "F24793")
    static let teal             = Color(hex: "59C9DD")
    static let lime             = Color(hex: "B7DE82")
    static let coral            = Color(hex: "F76378")
    static let success          = Color(hex: "AEE67B")
    static let warning          = crownGold
    static let danger           = coral

    // Background: warm dark party base that keeps the logo colors readable.
    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "17131B"), Color(hex: "24182B"), Color(hex: "331C35")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static var arenaBackground: some View { ArenaBackgroundView() }

    // Brand: logo hot pink into coral with a candy-pop finish.
    static let brandGradient = LinearGradient(
        colors: [Color.white, hotPink, coral],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let cardBackground   = Color.white.opacity(0.16)
    static let cardBorder       = Color.white.opacity(0.62)
    static let textPrimary      = Color.white
    static let textSecondary    = Color.white.opacity(0.84)
    static let accent           = hotPink
    static let accentBright     = hotPink

    // Each mode keeps its identity, tuned into the Puzzle Party logo palette.
    static func modeGradient(_ mode: GameMode) -> LinearGradient {
        switch mode {
        case .sudoku:
            return LinearGradient(colors: [teal, Color.white.opacity(0.78)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .minesweeper:
            return LinearGradient(colors: [coral, hotPink, crownGold],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .colorLink:
            return LinearGradient(colors: [teal, hotPink, lime],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .gridlock:
            return LinearGradient(colors: [crownGold, teal],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .anagram:
            return LinearGradient(colors: [hotPink, coral],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .wordHunt:
            return LinearGradient(colors: [teal, royalBlue],
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
                colors: [AppTheme.teal.opacity(0.13), .clear],
                center: .topLeading,
                startRadius: 24,
                endRadius: 420
            )
            RadialGradient(
                colors: [AppTheme.hotPink.opacity(0.20), .clear],
                center: .bottomTrailing,
                startRadius: 60,
                endRadius: 540
            )
            RadialGradient(
                colors: [AppTheme.lime.opacity(0.10), .clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 460
            )
            Canvas { context, size in
                let spacing: CGFloat = 34
                var grid = Path()
                for x in stride(from: CGFloat(0), through: size.width, by: spacing) {
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: CGFloat(0), through: size.height, by: spacing) {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(Color.white.opacity(0.045)), lineWidth: 0.5)

                let majorSpacing = spacing * 4
                var majorGrid = Path()
                for x in stride(from: CGFloat(0), through: size.width, by: majorSpacing) {
                    majorGrid.move(to: CGPoint(x: x, y: 0))
                    majorGrid.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: CGFloat(0), through: size.height, by: majorSpacing) {
                    majorGrid.move(to: CGPoint(x: 0, y: y))
                    majorGrid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(majorGrid, with: .color(AppTheme.hotPink.opacity(0.065)), lineWidth: 0.8)
            }
            .blendMode(.screen)
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
