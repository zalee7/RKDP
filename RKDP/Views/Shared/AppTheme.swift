import SwiftUI

enum AppTheme {
    // Puzzle Party palette: soft logo-inspired party blocks on a bright friendly base.
    static let iconBlue         = Color(hex: "5BCBE3")
    static let royalBlue        = Color(hex: "46B8D6")
    static let iconPurple       = Color(hex: "B78BE9")
    static let crownGold        = Color(hex: "D49A18")
    static let hotPink          = Color(hex: "F24793")
    static let teal             = Color(hex: "26AFC5")
    static let lime             = Color(hex: "7BBE36")
    static let coral            = Color(hex: "F76378")
    static let cream            = Color(hex: "FFF6E7")
    static let plum             = Color(hex: "372A3C")
    static let success          = Color(hex: "45B84D")
    static let warning          = crownGold
    static let danger           = coral

    // Background: soft pastel party base inspired by the Puzzle Party logo.
    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "FFF9F1"), Color(hex: "FFF1F7"), Color(hex: "EEF9FC")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static var arenaBackground: some View { ArenaBackgroundView() }

    // Brand: logo hot pink into coral with a candy-pop finish.
    static let brandGradient = LinearGradient(
        colors: [hotPink, coral],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let cardBackground   = Color.white.opacity(0.92)
    static let cardBorder       = plum.opacity(0.30)
    static let controlBackground = Color.white.opacity(0.96)
    static let controlBorder     = plum.opacity(0.28)
    static let tintedPanel       = Color(hex: "FFF2F8").opacity(0.72)
    static let textPrimary      = plum
    static let textSecondary    = plum.opacity(0.84)
    static let textMuted        = plum.opacity(0.66)
    static let textOnColor      = Color.white
    static let softShadow       = plum.opacity(0.16)
    static let accent           = hotPink
    static let accentBright     = hotPink
    static let selectedControlBackground = Color(hex: "FFF0F7")
    static let disabledControlBackground = Color(hex: "F2ECF1")
    static let progressTrack             = plum.opacity(0.22)

    // Each mode keeps its identity, tuned into the Puzzle Party logo palette.
    static func modeGradient(_ mode: GameMode) -> LinearGradient {
        switch mode {
        case .sudoku:
            return LinearGradient(colors: [teal, royalBlue],
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
            return LinearGradient(colors: [teal, Color(hex: "4FC8E8")],
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
        case .sudoku:      return royalBlue
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppPreferenceKeys.reduceExtraAnimations) private var reduceExtraAnimations = false
    @State private var animatePieces = false

    private var motionDisabled: Bool { reduceMotion || reduceExtraAnimations }
    private var shouldAnimate: Bool {
        !motionDisabled && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
            RadialGradient(
                colors: [AppTheme.hotPink.opacity(0.16), .clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 520
            )
            RadialGradient(
                colors: [AppTheme.teal.opacity(0.15), .clear],
                center: .topLeading,
                startRadius: 30,
                endRadius: 500
            )
            RadialGradient(
                colors: [AppTheme.crownGold.opacity(0.13), .clear],
                center: .bottomLeading,
                startRadius: 60,
                endRadius: 520
            )

            ForEach(PastelPuzzlePiece.all) { piece in
                PuzzlePieceBackgroundShape()
                    .fill(piece.color.opacity(piece.opacity))
                    .frame(width: piece.size, height: piece.size)
                    .rotationEffect(.degrees(piece.rotation + motion(piece.rotationDrift)))
                    .offset(x: piece.offset.width + motion(piece.drift.width),
                            y: piece.offset.height + motion(piece.drift.height))
                    .blur(radius: piece.blur)
                    .animation(shouldAnimate ? .easeInOut(duration: piece.duration).repeatForever(autoreverses: true).delay(piece.delay) : nil, value: animatePieces)
            }
        }
        .onAppear { animatePieces = shouldAnimate }
        .onDisappear { animatePieces = false }
        .onChange(of: reduceMotion) { _, isReduced in
            animatePieces = !(isReduced || reduceExtraAnimations || ProcessInfo.processInfo.isLowPowerModeEnabled)
        }
        .onChange(of: reduceExtraAnimations) { _, isReduced in
            animatePieces = !(isReduced || reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled)
        }
    }

    private func motion(_ value: CGFloat) -> CGFloat {
        guard shouldAnimate else { return 0 }
        return animatePieces ? value : -value
    }
}

private struct PastelPuzzlePiece: Identifiable {
    let id: Int
    let color: Color
    let size: CGFloat
    let offset: CGSize
    let drift: CGSize
    let rotation: CGFloat
    let rotationDrift: CGFloat
    let opacity: Double
    let blur: CGFloat
    let duration: Double
    let delay: Double

    static let all: [PastelPuzzlePiece] = [
        .init(id: 0, color: AppTheme.hotPink, size: 170, offset: CGSize(width: -155, height: -315), drift: CGSize(width: 18, height: 14), rotation: -14, rotationDrift: 5, opacity: 0.095, blur: 0.8, duration: 7.5, delay: 0.0),
        .init(id: 1, color: AppTheme.teal, size: 145, offset: CGSize(width: 168, height: -250), drift: CGSize(width: -14, height: 16), rotation: 18, rotationDrift: -4, opacity: 0.085, blur: 0.9, duration: 8.4, delay: 0.4),
        .init(id: 2, color: AppTheme.coral, size: 205, offset: CGSize(width: 170, height: 18), drift: CGSize(width: 16, height: -12), rotation: 10, rotationDrift: 4, opacity: 0.070, blur: 1.0, duration: 9.2, delay: 0.8),
        .init(id: 3, color: AppTheme.crownGold, size: 155, offset: CGSize(width: -190, height: 160), drift: CGSize(width: 14, height: -18), rotation: 24, rotationDrift: -5, opacity: 0.090, blur: 0.8, duration: 8.8, delay: 1.1),
        .init(id: 4, color: AppTheme.iconBlue, size: 190, offset: CGSize(width: -82, height: 345), drift: CGSize(width: -12, height: 16), rotation: -28, rotationDrift: 6, opacity: 0.075, blur: 1.1, duration: 10.0, delay: 0.2),
        .init(id: 5, color: AppTheme.hotPink, size: 128, offset: CGSize(width: 210, height: 355), drift: CGSize(width: -18, height: -10), rotation: 34, rotationDrift: -6, opacity: 0.070, blur: 0.9, duration: 8.0, delay: 1.5)
    ]
}

private struct PuzzlePieceBackgroundShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let y = rect.minY
        var path = Path()
        path.move(to: CGPoint(x: x + w * 0.18, y: y + h * 0.12))
        path.addLine(to: CGPoint(x: x + w * 0.40, y: y + h * 0.12))
        path.addCurve(
            to: CGPoint(x: x + w * 0.60, y: y + h * 0.12),
            control1: CGPoint(x: x + w * 0.40, y: y - h * 0.08),
            control2: CGPoint(x: x + w * 0.60, y: y - h * 0.08)
        )
        path.addLine(to: CGPoint(x: x + w * 0.82, y: y + h * 0.12))
        path.addLine(to: CGPoint(x: x + w * 0.82, y: y + h * 0.40))
        path.addCurve(
            to: CGPoint(x: x + w * 0.82, y: y + h * 0.60),
            control1: CGPoint(x: x + w * 1.04, y: y + h * 0.40),
            control2: CGPoint(x: x + w * 1.04, y: y + h * 0.60)
        )
        path.addLine(to: CGPoint(x: x + w * 0.82, y: y + h * 0.88))
        path.addLine(to: CGPoint(x: x + w * 0.58, y: y + h * 0.88))
        path.addCurve(
            to: CGPoint(x: x + w * 0.42, y: y + h * 0.88),
            control1: CGPoint(x: x + w * 0.57, y: y + h * 1.06),
            control2: CGPoint(x: x + w * 0.43, y: y + h * 1.06)
        )
        path.addLine(to: CGPoint(x: x + w * 0.18, y: y + h * 0.88))
        path.addLine(to: CGPoint(x: x + w * 0.18, y: y + h * 0.60))
        path.addCurve(
            to: CGPoint(x: x + w * 0.18, y: y + h * 0.40),
            control1: CGPoint(x: x - w * 0.04, y: y + h * 0.60),
            control2: CGPoint(x: x - w * 0.04, y: y + h * 0.40)
        )
        path.closeSubpath()
        return path
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
