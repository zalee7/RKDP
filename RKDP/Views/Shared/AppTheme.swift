import SwiftUI

enum AppTheme {
    // Icon palette: electric arcade blue/purple with candy blocks and a gold crown.
    static let iconBlue         = Color(hex: "168CFF")
    static let royalBlue        = Color(hex: "256BFF")
    static let iconPurple       = Color(hex: "7B42FF")
    static let crownGold        = Color(hex: "FFD02E")
    static let hotPink          = Color(hex: "FF2F78")
    static let teal             = Color(hex: "12C8A2")
    static let success          = Color(hex: "2EEA9D")
    static let warning          = Color(hex: "FFD02E")
    static let danger           = Color(hex: "FF4A7D")

    // Background: dark grid-arena base that lets mode colors and rank icons pop.
    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "070B24"), Color(hex: "171044"), Color(hex: "260F3E")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static var arenaBackground: some View { ArenaBackgroundView() }

    // Brand: crown gold into jewel pink.
    static let brandGradient = LinearGradient(
        colors: [crownGold, hotPink],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let cardBackground   = Color.white.opacity(0.20)
    static let cardBorder       = Color.white.opacity(0.50)
    static let textPrimary      = Color.white
    static let textSecondary    = Color.white.opacity(0.86)
    static let accent           = hotPink
    static let accentBright     = crownGold

    // Each mode keeps its identity, tuned into the icon palette.
    static func modeGradient(_ mode: GameMode) -> LinearGradient {
        switch mode {
        case .sudoku:
            return LinearGradient(colors: [iconBlue, Color(hex: "34D9FF")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .minesweeper:
            return LinearGradient(colors: [hotPink, crownGold],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .colorLink:
            return LinearGradient(colors: [teal, hotPink, royalBlue],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .gridlock:
            return LinearGradient(colors: [crownGold, iconBlue],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .anagram:
            return LinearGradient(colors: [hotPink, iconPurple],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .wordHunt:
            return LinearGradient(colors: [Color(hex: "39D5FF"), royalBlue],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .wordle:
            return LinearGradient(colors: [Color(hex: "50C878"), teal],
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
        case .wordle:      return Color(hex: "538D4E")
        }
    }
}

private struct ArenaBackgroundView: View {
    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
            RadialGradient(
                colors: [AppTheme.crownGold.opacity(0.12), .clear],
                center: .topLeading,
                startRadius: 24,
                endRadius: 420
            )
            RadialGradient(
                colors: [AppTheme.hotPink.opacity(0.15), .clear],
                center: .bottomTrailing,
                startRadius: 60,
                endRadius: 540
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
                context.stroke(majorGrid, with: .color(AppTheme.crownGold.opacity(0.055)), lineWidth: 0.8)
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
