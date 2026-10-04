import SwiftUI

// MARK: - Applied theme styles (what views actually use)

struct BoardThemeStyle {
    var cellBackground: Color
    var selectedCell: Color
    var highlightedCell: Color
    var invalidCell: Color
    var gridLineMajor: Color
    var gridLineMinor: Color
    var tileGradient: LinearGradient
    var activeTraceColor: Color
}

struct NumberFontStyle {
    var design: Font.Design
    var weight: Font.Weight
}

struct TileThemeStyle {
    var fill: LinearGradient
    var inactiveFill: Color
    var border: Color
    var textColor: Color
    var accent: Color
    var shadow: Color
    var cornerScale: CGFloat
}

struct CardThemeStyle {
    var tableTint: Color
    var frontFill: LinearGradient
    var backFill: LinearGradient
    var border: Color
    var redSuit: Color
    var blackSuit: Color
    var accent: Color
    var shadow: Color
    var backSymbol: String
}

extension OwnedCosmetics {
    var themeStyle: BoardThemeStyle {
        switch equippedBoardTheme {
        case "theme_dark":
            return BoardThemeStyle(
                cellBackground: Color(hex: "0A0A1A").opacity(0.6),
                selectedCell: Color(hex: "5B21B6").opacity(0.5),
                highlightedCell: Color(hex: "312E81").opacity(0.3),
                invalidCell: Color.red.opacity(0.25),
                gridLineMajor: Color.white.opacity(0.5),
                gridLineMinor: Color.white.opacity(0.12),
                tileGradient: LinearGradient(colors: [Color(hex: "374151"), Color(hex: "1F2937")], startPoint: .topLeading, endPoint: .bottomTrailing),
                activeTraceColor: Color(hex: "A78BFA")
            )
        case "theme_ocean":
            return BoardThemeStyle(
                cellBackground: Color(hex: "0077B6").opacity(0.15),
                selectedCell: Color(hex: "0096C7").opacity(0.5),
                highlightedCell: Color(hex: "ADE8F4").opacity(0.15),
                invalidCell: Color.red.opacity(0.25),
                gridLineMajor: Color(hex: "0096C7"),
                gridLineMinor: Color(hex: "ADE8F4").opacity(0.4),
                tileGradient: LinearGradient(colors: [Color(hex: "0077B6"), Color(hex: "00B4D8")], startPoint: .topLeading, endPoint: .bottomTrailing),
                activeTraceColor: Color(hex: "90E0EF")
            )
        case "theme_forest":
            return BoardThemeStyle(
                cellBackground: Color(hex: "1B4332").opacity(0.2),
                selectedCell: Color(hex: "52B788").opacity(0.45),
                highlightedCell: Color(hex: "95D5B2").opacity(0.15),
                invalidCell: Color.red.opacity(0.25),
                gridLineMajor: Color(hex: "40916C"),
                gridLineMinor: Color(hex: "95D5B2").opacity(0.35),
                tileGradient: LinearGradient(colors: [Color(hex: "2D6A4F"), Color(hex: "52B788")], startPoint: .topLeading, endPoint: .bottomTrailing),
                activeTraceColor: Color(hex: "B7E4C7")
            )
        case "theme_neon":
            return BoardThemeStyle(
                cellBackground: Color(hex: "0D0221").opacity(0.5),
                selectedCell: Color(hex: "FF00FF").opacity(0.4),
                highlightedCell: Color(hex: "BC00DD").opacity(0.2),
                invalidCell: Color.red.opacity(0.35),
                gridLineMajor: Color(hex: "FF00FF").opacity(0.8),
                gridLineMinor: Color(hex: "7B00D4").opacity(0.4),
                tileGradient: LinearGradient(colors: [Color(hex: "FF0099"), Color(hex: "7700FF")], startPoint: .topLeading, endPoint: .bottomTrailing),
                activeTraceColor: Color(hex: "00FFFF")
            )
        case "theme_gold", "theme_crown_gold":
            return BoardThemeStyle(
                cellBackground: Color(hex: "78350F").opacity(0.15),
                selectedCell: Color(hex: "FFD02E").opacity(0.45),
                highlightedCell: Color(hex: "FFF0A3").opacity(0.18),
                invalidCell: Color.red.opacity(0.25),
                gridLineMajor: Color(hex: "FFD02E"),
                gridLineMinor: Color(hex: "FFF0A3").opacity(0.42),
                tileGradient: LinearGradient(colors: [Color(hex: "FFD02E"), Color(hex: "FF2F78")], startPoint: .topLeading, endPoint: .bottomTrailing),
                activeTraceColor: Color(hex: "FFF0A3")
            )
        case "theme_color_link":
            return BoardThemeStyle(
                cellBackground: Color(hex: "083B5F").opacity(0.18),
                selectedCell: Color(hex: "12C8A2").opacity(0.42),
                highlightedCell: Color(hex: "FF2F78").opacity(0.16),
                invalidCell: Color.red.opacity(0.25),
                gridLineMajor: Color(hex: "12C8A2"),
                gridLineMinor: Color.white.opacity(0.28),
                tileGradient: LinearGradient(colors: [Color(hex: "12C8A2"), Color(hex: "FF2F78"), Color(hex: "256BFF")], startPoint: .topLeading, endPoint: .bottomTrailing),
                activeTraceColor: Color(hex: "12C8A2")
            )
        case "theme_grid_duel":
            return BoardThemeStyle(
                cellBackground: Color(hex: "123A7A").opacity(0.16),
                selectedCell: Color(hex: "FFD02E").opacity(0.42),
                highlightedCell: Color(hex: "168CFF").opacity(0.18),
                invalidCell: Color.red.opacity(0.25),
                gridLineMajor: Color(hex: "FFD02E"),
                gridLineMinor: Color(hex: "168CFF").opacity(0.4),
                tileGradient: LinearGradient(colors: [Color(hex: "FFD02E"), Color(hex: "168CFF")], startPoint: .topLeading, endPoint: .bottomTrailing),
                activeTraceColor: Color(hex: "FFD02E")
            )
        case "theme_word_neon":
            return BoardThemeStyle(
                cellBackground: Color(hex: "24104F").opacity(0.2),
                selectedCell: Color(hex: "FF2F78").opacity(0.44),
                highlightedCell: Color(hex: "7B42FF").opacity(0.22),
                invalidCell: Color.red.opacity(0.3),
                gridLineMajor: Color(hex: "FF2F78"),
                gridLineMinor: Color(hex: "39D5FF").opacity(0.35),
                tileGradient: LinearGradient(colors: [Color(hex: "FF2F78"), Color(hex: "7B42FF"), Color(hex: "39D5FF")], startPoint: .topLeading, endPoint: .bottomTrailing),
                activeTraceColor: Color(hex: "39D5FF")
            )
        case "theme_mine_pulse":
            return BoardThemeStyle(
                cellBackground: Color(hex: "28091B").opacity(0.2),
                selectedCell: Color(hex: "FF4A7D").opacity(0.45),
                highlightedCell: Color(hex: "FFD02E").opacity(0.18),
                invalidCell: Color(hex: "FF4A7D").opacity(0.35),
                gridLineMajor: Color(hex: "FF4A7D"),
                gridLineMinor: Color(hex: "FFD02E").opacity(0.35),
                tileGradient: LinearGradient(colors: [Color(hex: "FF4A7D"), Color(hex: "FFD02E")], startPoint: .topLeading, endPoint: .bottomTrailing),
                activeTraceColor: Color(hex: "FFD02E")
            )
        case "theme_arcade_cabinet":
            return BoardThemeStyle(
                cellBackground: Color(hex: "171B43").opacity(0.2),
                selectedCell: Color(hex: "39D5FF").opacity(0.4),
                highlightedCell: Color(hex: "FF2F78").opacity(0.16),
                invalidCell: Color.red.opacity(0.3),
                gridLineMajor: Color(hex: "39D5FF"),
                gridLineMinor: Color(hex: "FF2F78").opacity(0.34),
                tileGradient: LinearGradient(colors: [Color(hex: "2D2A7F"), Color(hex: "39D5FF"), Color(hex: "FF2F78")], startPoint: .topLeading, endPoint: .bottomTrailing),
                activeTraceColor: Color(hex: "39D5FF")
            )
        case "theme_bubblegum":
            return BoardThemeStyle(
                cellBackground: Color(hex: "FFF0FA").opacity(0.36),
                selectedCell: Color(hex: "FF9ED1").opacity(0.5),
                highlightedCell: Color(hex: "39D5FF").opacity(0.18),
                invalidCell: Color.red.opacity(0.24),
                gridLineMajor: Color(hex: "FF7FB7"),
                gridLineMinor: Color(hex: "39D5FF").opacity(0.36),
                tileGradient: LinearGradient(colors: [Color(hex: "FF9ED1"), Color(hex: "39D5FF")], startPoint: .topLeading, endPoint: .bottomTrailing),
                activeTraceColor: Color(hex: "FF2F78")
            )
        case "theme_starlight":
            return BoardThemeStyle(
                cellBackground: Color(hex: "08142E").opacity(0.22),
                selectedCell: Color(hex: "78D7FF").opacity(0.38),
                highlightedCell: Color(hex: "B28CFF").opacity(0.2),
                invalidCell: Color.red.opacity(0.28),
                gridLineMajor: Color(hex: "78D7FF"),
                gridLineMinor: Color.white.opacity(0.34),
                tileGradient: LinearGradient(colors: [Color(hex: "08142E"), Color(hex: "78D7FF"), Color(hex: "B28CFF")], startPoint: .topLeading, endPoint: .bottomTrailing),
                activeTraceColor: Color(hex: "E8F7FF")
            )
        case "theme_lava_rescue":
            return BoardThemeStyle(
                cellBackground: Color(hex: "301006").opacity(0.24),
                selectedCell: Color(hex: "FF6B1A").opacity(0.44),
                highlightedCell: Color(hex: "FFD02E").opacity(0.18),
                invalidCell: Color(hex: "FF2F78").opacity(0.34),
                gridLineMajor: Color(hex: "FF6B1A"),
                gridLineMinor: Color(hex: "FFD02E").opacity(0.34),
                tileGradient: LinearGradient(colors: [Color(hex: "FF6B1A"), Color(hex: "FFD02E"), Color(hex: "FF2F78")], startPoint: .topLeading, endPoint: .bottomTrailing),
                activeTraceColor: Color(hex: "FFD02E")
            )
        case "theme_crystal_cove":
            return BoardThemeStyle(
                cellBackground: Color(hex: "E8F7FF").opacity(0.24),
                selectedCell: Color(hex: "78D7FF").opacity(0.46),
                highlightedCell: Color(hex: "12C8A2").opacity(0.18),
                invalidCell: Color.red.opacity(0.24),
                gridLineMajor: Color(hex: "78D7FF"),
                gridLineMinor: Color.white.opacity(0.58),
                tileGradient: LinearGradient(colors: [Color(hex: "E8F7FF"), Color(hex: "78D7FF"), Color(hex: "12C8A2")], startPoint: .topLeading, endPoint: .bottomTrailing),
                activeTraceColor: Color(hex: "12C8A2")
            )
        case "theme_midnight_mint":
            return BoardThemeStyle(
                cellBackground: Color(hex: "071D24").opacity(0.26),
                selectedCell: Color(hex: "12C8A2").opacity(0.42),
                highlightedCell: Color(hex: "8FFFE1").opacity(0.16),
                invalidCell: Color.red.opacity(0.28),
                gridLineMajor: Color(hex: "12C8A2"),
                gridLineMinor: Color(hex: "8FFFE1").opacity(0.32),
                tileGradient: LinearGradient(colors: [Color(hex: "071D24"), Color(hex: "12C8A2")], startPoint: .topLeading, endPoint: .bottomTrailing),
                activeTraceColor: Color(hex: "8FFFE1")
            )
        case "theme_prism_party":
            return BoardThemeStyle(
                cellBackground: Color(hex: "171A3A").opacity(0.88),
                selectedCell: Color(hex: "FF4F91").opacity(0.68),
                highlightedCell: Color(hex: "7266D9").opacity(0.34),
                invalidCell: Color.red.opacity(0.3),
                gridLineMajor: Color(hex: "A89CFF").opacity(0.78),
                gridLineMinor: Color(hex: "8D86D9").opacity(0.38),
                tileGradient: LinearGradient(colors: [Color(hex: "151833"), Color(hex: "2A2454")], startPoint: .topLeading, endPoint: .bottomTrailing),
                activeTraceColor: Color(hex: "FFD36B")
            )
        case "theme_royal_arcade":
            return BoardThemeStyle(
                cellBackground: Color(hex: "170A3A").opacity(0.24),
                selectedCell: Color(hex: "FFD02E").opacity(0.44),
                highlightedCell: Color(hex: "7B42FF").opacity(0.22),
                invalidCell: Color.red.opacity(0.3),
                gridLineMajor: Color(hex: "FFD02E"),
                gridLineMinor: Color(hex: "FF2F78").opacity(0.34),
                tileGradient: LinearGradient(colors: [Color(hex: "7B42FF"), Color(hex: "FF2F78"), Color(hex: "FFD02E")], startPoint: .topLeading, endPoint: .bottomTrailing),
                activeTraceColor: Color(hex: "FFD02E")
            )
        case "theme_cosmic_crown":
            return BoardThemeStyle(
                cellBackground: Color(hex: "050510").opacity(0.28),
                selectedCell: Color(hex: "FFD02E").opacity(0.42),
                highlightedCell: Color(hex: "78D7FF").opacity(0.2),
                invalidCell: Color.red.opacity(0.3),
                gridLineMajor: Color(hex: "FFD02E"),
                gridLineMinor: Color(hex: "78D7FF").opacity(0.34),
                tileGradient: LinearGradient(colors: [Color(hex: "050510"), Color(hex: "256BFF"), Color(hex: "FFD02E")], startPoint: .topLeading, endPoint: .bottomTrailing),
                activeTraceColor: Color(hex: "FFD02E")
            )
        default: // theme_classic
            return BoardThemeStyle(
                cellBackground: .clear,
                selectedCell: Color.blue.opacity(0.35),
                highlightedCell: Color.blue.opacity(0.1),
                invalidCell: Color.red.opacity(0.2),
                gridLineMajor: Color.primary,
                gridLineMinor: Color.primary.opacity(0.3),
                tileGradient: LinearGradient(colors: [Color(hex: "FF6B35"), Color(hex: "F72585")], startPoint: .topLeading, endPoint: .bottomTrailing),
                activeTraceColor: Color.white.opacity(0.55)
            )
        }
    }

    var fontStyle: NumberFontStyle {
        switch equippedNumberFont {
        case "font_pixel":   return NumberFontStyle(design: .monospaced, weight: .medium)
        case "font_bold":    return NumberFontStyle(design: .default,    weight: .heavy)
        case "font_elegant": return NumberFontStyle(design: .serif,      weight: .light)
        default:             return NumberFontStyle(design: .default,    weight: .regular)
        }
    }

    var tileThemeStyle: TileThemeStyle {
        switch equippedTileTheme {
        case "tile_neon_pop":
            return TileThemeStyle(
                fill: LinearGradient(colors: [Color(hex: "FF2F78"), Color(hex: "7B42FF")], startPoint: .topLeading, endPoint: .bottomTrailing),
                inactiveFill: Color(hex: "1A1038").opacity(0.72),
                border: Color(hex: "39D5FF").opacity(0.72),
                textColor: .white,
                accent: Color(hex: "39D5FF"),
                shadow: Color(hex: "FF2F78").opacity(0.34),
                cornerScale: 0.24
            )
        case "tile_crown_gold":
            return TileThemeStyle(
                fill: LinearGradient(colors: [Color(hex: "FFD02E"), Color(hex: "FF9E2C")], startPoint: .topLeading, endPoint: .bottomTrailing),
                inactiveFill: Color(hex: "2A1B05").opacity(0.72),
                border: Color(hex: "FFF0A3").opacity(0.82),
                textColor: Color(hex: "231200"),
                accent: Color(hex: "FFD02E"),
                shadow: Color(hex: "FFD02E").opacity(0.36),
                cornerScale: 0.24
            )
        case "tile_mint_glass":
            return TileThemeStyle(
                fill: LinearGradient(colors: [Color(hex: "12C8A2"), Color(hex: "39D5FF")], startPoint: .topLeading, endPoint: .bottomTrailing),
                inactiveFill: Color(hex: "072D36").opacity(0.70),
                border: Color(hex: "8FFFE1").opacity(0.72),
                textColor: .white,
                accent: Color(hex: "12C8A2"),
                shadow: Color(hex: "12C8A2").opacity(0.30),
                cornerScale: 0.26
            )
        case "tile_lava_core":
            return TileThemeStyle(
                fill: LinearGradient(colors: [Color(hex: "FF5A1F"), Color(hex: "FF2F78")], startPoint: .topLeading, endPoint: .bottomTrailing),
                inactiveFill: Color(hex: "301006").opacity(0.72),
                border: Color(hex: "FFD02E").opacity(0.76),
                textColor: .white,
                accent: Color(hex: "FF5A1F"),
                shadow: Color(hex: "FF5A1F").opacity(0.34),
                cornerScale: 0.22
            )
        case "tile_diamond":
            return TileThemeStyle(
                fill: LinearGradient(colors: [Color(hex: "E8F7FF"), Color(hex: "78D7FF"), Color(hex: "B28CFF")], startPoint: .topLeading, endPoint: .bottomTrailing),
                inactiveFill: Color(hex: "102033").opacity(0.72),
                border: Color.white.opacity(0.88),
                textColor: Color(hex: "12203D"),
                accent: Color(hex: "78D7FF"),
                shadow: Color(hex: "78D7FF").opacity(0.38),
                cornerScale: 0.18
            )
        case "tile_bubblegum":
            return TileThemeStyle(
                fill: LinearGradient(colors: [Color(hex: "FF9ED1"), Color(hex: "39D5FF")], startPoint: .topLeading, endPoint: .bottomTrailing),
                inactiveFill: Color(hex: "FFF0FA").opacity(0.74),
                border: Color(hex: "FF7FB7").opacity(0.76),
                textColor: Color(hex: "4B2140"),
                accent: Color(hex: "FF2F78"),
                shadow: Color(hex: "FF9ED1").opacity(0.28),
                cornerScale: 0.28
            )
        case "tile_arcade_buttons":
            return TileThemeStyle(
                fill: LinearGradient(colors: [Color(hex: "39D5FF"), Color(hex: "FF2F78")], startPoint: .topLeading, endPoint: .bottomTrailing),
                inactiveFill: Color(hex: "151A40").opacity(0.72),
                border: Color.white.opacity(0.74),
                textColor: .white,
                accent: Color(hex: "39D5FF"),
                shadow: Color(hex: "39D5FF").opacity(0.32),
                cornerScale: 0.5
            )
        case "tile_royal_blue":
            return TileThemeStyle(
                fill: LinearGradient(colors: [Color(hex: "71C8FF"), Color(hex: "256BFF")], startPoint: .topLeading, endPoint: .bottomTrailing),
                inactiveFill: Color(hex: "0A163A").opacity(0.72),
                border: Color(hex: "A7D8FF").opacity(0.8),
                textColor: .white,
                accent: Color(hex: "71C8FF"),
                shadow: Color(hex: "256BFF").opacity(0.34),
                cornerScale: 0.2
            )
        case "tile_starlight":
            return TileThemeStyle(
                fill: LinearGradient(colors: [Color(hex: "E8F7FF"), Color(hex: "78D7FF"), Color(hex: "B28CFF")], startPoint: .topLeading, endPoint: .bottomTrailing),
                inactiveFill: Color(hex: "08142E").opacity(0.74),
                border: Color.white.opacity(0.86),
                textColor: Color(hex: "12203D"),
                accent: Color(hex: "E8F7FF"),
                shadow: Color(hex: "78D7FF").opacity(0.34),
                cornerScale: 0.18
            )
        case "tile_prism_pop":
            return TileThemeStyle(
                fill: LinearGradient(colors: [Color(hex: "FF2F78"), Color(hex: "7B42FF"), Color(hex: "12C8A2")], startPoint: .topLeading, endPoint: .bottomTrailing),
                inactiveFill: Color(hex: "291047").opacity(0.72),
                border: Color(hex: "FFD02E").opacity(0.72),
                textColor: .white,
                accent: Color(hex: "FFD02E"),
                shadow: Color(hex: "FF2F78").opacity(0.36),
                cornerScale: 0.24
            )
        case "tile_crystal":
            return TileThemeStyle(
                fill: LinearGradient(colors: [Color(hex: "F4FDFF"), Color(hex: "B8EEF4"), Color(hex: "68C8D5")], startPoint: .topLeading, endPoint: .bottomTrailing),
                inactiveFill: Color(hex: "0B2631").opacity(0.92),
                border: Color(hex: "D9FBFF").opacity(0.88),
                textColor: Color(hex: "082E3A"),
                accent: Color(hex: "83DDE8"),
                shadow: Color(hex: "49B9CA").opacity(0.28),
                cornerScale: 0.14
            )
        case "tile_midnight_mint":
            return TileThemeStyle(
                fill: LinearGradient(colors: [Color(hex: "071D24"), Color(hex: "12C8A2")], startPoint: .topLeading, endPoint: .bottomTrailing),
                inactiveFill: Color(hex: "061318").opacity(0.78),
                border: Color(hex: "8FFFE1").opacity(0.76),
                textColor: .white,
                accent: Color(hex: "8FFFE1"),
                shadow: Color(hex: "12C8A2").opacity(0.34),
                cornerScale: 0.24
            )
        case "tile_plasma":
            return TileThemeStyle(
                fill: LinearGradient(colors: [Color(hex: "FF6B1A"), Color(hex: "FF2F78"), Color(hex: "7B42FF")], startPoint: .topLeading, endPoint: .bottomTrailing),
                inactiveFill: Color(hex: "25071A").opacity(0.74),
                border: Color(hex: "FFD02E").opacity(0.78),
                textColor: .white,
                accent: Color(hex: "FFD02E"),
                shadow: Color(hex: "FF2F78").opacity(0.38),
                cornerScale: 0.22
            )
        case "tile_cosmic":
            return TileThemeStyle(
                fill: LinearGradient(colors: [Color(hex: "050510"), Color(hex: "256BFF"), Color(hex: "FFD02E")], startPoint: .topLeading, endPoint: .bottomTrailing),
                inactiveFill: Color(hex: "050510").opacity(0.82),
                border: Color(hex: "FFD02E").opacity(0.88),
                textColor: .white,
                accent: Color(hex: "FFD02E"),
                shadow: Color(hex: "FFD02E").opacity(0.42),
                cornerScale: 0.18
            )
        case "tile_royal_crown":
            return TileThemeStyle(
                fill: LinearGradient(colors: [Color(hex: "FFD02E"), Color(hex: "FF2F78")], startPoint: .topLeading, endPoint: .bottomTrailing),
                inactiveFill: Color(hex: "2A1B05").opacity(0.76),
                border: Color(hex: "FFF0A3").opacity(0.9),
                textColor: Color(hex: "231200"),
                accent: Color(hex: "FFD02E"),
                shadow: Color(hex: "FFD02E").opacity(0.44),
                cornerScale: 0.2
            )
        default:
            return TileThemeStyle(
                fill: themeStyle.tileGradient,
                inactiveFill: AppTheme.cardBackground,
                border: Color.white.opacity(0.24),
                textColor: .white,
                accent: themeStyle.activeTraceColor,
                shadow: Color.black.opacity(0.22),
                cornerScale: 0.22
            )
        }
    }

    var cardThemeStyle: CardThemeStyle {
        switch equippedCardTheme {
        case "card_crown_casino":
            return CardThemeStyle(
                tableTint: Color(hex: "173C5F"),
                frontFill: LinearGradient(colors: [Color(hex: "FFF9E8"), Color(hex: "FFEAB0")], startPoint: .topLeading, endPoint: .bottomTrailing),
                backFill: LinearGradient(colors: [Color(hex: "123A7A"), Color(hex: "FFD02E")], startPoint: .topLeading, endPoint: .bottomTrailing),
                border: Color(hex: "FFD02E"),
                redSuit: Color(hex: "D81B60"),
                blackSuit: Color(hex: "123A7A"),
                accent: Color(hex: "FFD02E"),
                shadow: Color(hex: "FFD02E").opacity(0.34),
                backSymbol: "crown.fill"
            )
        case "card_arcade_pink":
            return CardThemeStyle(
                tableTint: Color(hex: "321047"),
                frontFill: LinearGradient(colors: [Color.white, Color(hex: "FFE6F2")], startPoint: .topLeading, endPoint: .bottomTrailing),
                backFill: LinearGradient(colors: [Color(hex: "FF2F78"), Color(hex: "7B42FF"), Color(hex: "39D5FF")], startPoint: .topLeading, endPoint: .bottomTrailing),
                border: Color(hex: "FF2F78"),
                redSuit: Color(hex: "FF2F78"),
                blackSuit: Color(hex: "256BFF"),
                accent: Color(hex: "39D5FF"),
                shadow: Color(hex: "FF2F78").opacity(0.32),
                backSymbol: "sparkles"
            )
        case "card_royal_blue":
            return CardThemeStyle(
                tableTint: Color(hex: "0B1A40"),
                frontFill: LinearGradient(colors: [Color(hex: "F4FAFF"), Color(hex: "D9ECFF")], startPoint: .topLeading, endPoint: .bottomTrailing),
                backFill: LinearGradient(colors: [Color(hex: "071D55"), Color(hex: "256BFF"), Color(hex: "71C8FF")], startPoint: .topLeading, endPoint: .bottomTrailing),
                border: Color(hex: "71C8FF"),
                redSuit: Color(hex: "D81B60"),
                blackSuit: Color(hex: "123A7A"),
                accent: Color(hex: "71C8FF"),
                shadow: Color(hex: "256BFF").opacity(0.34),
                backSymbol: "diamond.fill"
            )
        case "card_cosmic_gold":
            return CardThemeStyle(
                tableTint: Color(hex: "050510"),
                frontFill: LinearGradient(colors: [Color(hex: "FFF8DC"), Color(hex: "E8F7FF")], startPoint: .topLeading, endPoint: .bottomTrailing),
                backFill: LinearGradient(colors: [Color(hex: "050510"), Color(hex: "256BFF"), Color(hex: "FFD02E")], startPoint: .topLeading, endPoint: .bottomTrailing),
                border: Color(hex: "FFD02E"),
                redSuit: Color(hex: "FF2F78"),
                blackSuit: Color(hex: "050510"),
                accent: Color(hex: "FFD02E"),
                shadow: Color(hex: "FFD02E").opacity(0.42),
                backSymbol: "star.fill"
            )
        default:
            return CardThemeStyle(
                tableTint: Color(hex: "153C33"),
                frontFill: LinearGradient(colors: [Color.white, Color(hex: "F6F8FB")], startPoint: .topLeading, endPoint: .bottomTrailing),
                backFill: LinearGradient(colors: [AppTheme.royalBlue, AppTheme.hotPink], startPoint: .topLeading, endPoint: .bottomTrailing),
                border: Color.black.opacity(0.16),
                redSuit: AppTheme.hotPink,
                blackSuit: AppTheme.royalBlue,
                accent: AppTheme.teal,
                shadow: Color.black.opacity(0.16),
                backSymbol: "sparkles"
            )
        }
    }
}

// MARK: - SwiftUI Environment

struct BoardCosmeticsKey: EnvironmentKey {
    static let defaultValue: OwnedCosmetics = .default
}

extension EnvironmentValues {
    var boardCosmetics: OwnedCosmetics {
        get { self[BoardCosmeticsKey.self] }
        set { self[BoardCosmeticsKey.self] = newValue }
    }
}

// MARK: - Shop item types

enum CosmeticCategory: String, Codable, CaseIterable {
    case title        = "Name Titles"
    case boardTheme   = "Board / Background Themes"
    case tileTheme    = "Tile Themes"
    case cardTheme    = "Card Themes"
    case numberFont   = "Number Style"
    case cellBorder   = "Cell Border"
    case avatarHead   = "Avatar Head"
    case avatarFace   = "Avatar Face"
    case avatarOutfit = "Avatar Outfit"
    case avatarAura   = "Avatar Aura"
    case avatarPose   = "Avatar Pose"

    var isAvatarCategory: Bool {
        switch self {
        case .avatarHead, .avatarFace, .avatarOutfit, .avatarAura, .avatarPose: return true
        default: return false
        }
    }

    var isLegacyStoreCategory: Bool {
        self == .numberFont || self == .cellBorder
    }
}

enum CosmeticRarity: String, CaseIterable {
    case free = "Free"
    case common = "Common"
    case rare = "Rare"
    case epic = "Epic"
    case legendary = "Legendary"

    static func forPrice(_ price: Int) -> CosmeticRarity {
        switch price {
        case 0: return .free
        case 1...499: return .common
        case 500...1_199: return .rare
        case 1_200...2_499: return .epic
        default: return .legendary
        }
    }

    var duplicateRefund: Int {
        switch self {
        case .free: return 0
        case .common: return 100
        case .rare: return 250
        case .epic: return 600
        case .legendary: return 1_000
        }
    }

    var badgeColor: Color {
        switch self {
        case .free: return Color.white.opacity(0.42)
        case .common: return AppTheme.teal
        case .rare: return AppTheme.royalBlue
        case .epic: return AppTheme.hotPink
        case .legendary: return AppTheme.crownGold
        }
    }

    var textColor: Color {
        switch self {
        case .free, .common, .legendary: return AppTheme.textPrimary
        case .rare, .epic: return AppTheme.textOnColor
        }
    }
}

struct CosmeticItem: Identifiable, Codable {
    var id: String
    var name: String
    var category: CosmeticCategory
    var price: Int
    var previewImageName: String
    var description: String

    var rarity: CosmeticRarity { CosmeticRarity.forPrice(price) }
}

extension CosmeticItem {
    var isLaunchCatalogVisible: Bool {
        switch category {
        case .avatarHead:
            return CosmeticCatalog.launchHeadIDs.contains(id)
        case .avatarFace:
            return CosmeticCatalog.launchExpressionIDs.contains(id)
        case .avatarAura:
            return CosmeticCatalog.launchAuraIDs.contains(id)
        case .avatarOutfit:
            return CosmeticCatalog.launchBodyIDs.contains(id)
        default:
            return true
        }
    }
}

enum CosmeticPackKind: String, CaseIterable, Identifiable, Codable {
    case avatar
    case theme

    var id: String { rawValue }

    var title: String {
        switch self {
        case .avatar: return "Puzzle Avatar Pack"
        case .theme: return "Puzzle Theme Pack"
        }
    }

    var subtitle: String {
        switch self {
        case .avatar: return "Unlocks one avatar cosmetic."
        case .theme: return "Unlocks one board or tile theme."
        }
    }

    var price: Int {
        switch self {
        case .avatar: return 1_250
        case .theme: return 950
        }
    }

    var iconName: String {
        switch self {
        case .avatar: return "face.smiling.fill"
        case .theme: return "paintpalette.fill"
        }
    }

    var eligibleCategories: [CosmeticCategory] {
        switch self {
        case .avatar:
            return [.avatarHead, .avatarFace, .avatarOutfit, .avatarAura]
        case .theme:
            return [.boardTheme, .tileTheme]
        }
    }

    var odds: [(rarity: CosmeticRarity, percent: Int)] {
        [
            (.common, 55),
            (.rare, 30),
            (.epic, 12),
            (.legendary, 3)
        ]
    }
}

struct CosmeticPackOpenResult {
    var kind: CosmeticPackKind
    var item: CosmeticItem
    var coinsSpent: Int
    var rolledRarity: CosmeticRarity
    var isDuplicate: Bool
    var duplicateRefund: Int
}

struct CosmeticPackOpenResponse {
    var user: AppUser
    var result: CosmeticPackOpenResult
}

struct AvatarStyle: Codable, Equatable {
    var head: String
    var face: String
    var outfit: String
    var aura: String
    var pose: String
    var bodyHex: String

    static let defaultBodyHex = "FF2F78"

    static let `default` = AvatarStyle(
        head: "avatar_head_none",
        face: "avatar_face_smile",
        outfit: "avatar_outfit_basic",
        aura: "avatar_aura_none",
        pose: "avatar_pose_jump",
        bodyHex: defaultBodyHex
    )

    enum CodingKeys: String, CodingKey {
        case head, face, outfit, aura, pose, bodyHex
    }

    init(head: String, face: String, outfit: String, aura: String, pose: String, bodyHex: String = AvatarStyle.defaultBodyHex) {
        self.head = head
        self.face = face
        self.outfit = outfit
        self.aura = aura
        self.pose = pose
        self.bodyHex = OwnedCosmetics.normalizedHex(bodyHex) ?? AvatarStyle.defaultBodyHex
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        head = try c.decodeIfPresent(String.self, forKey: .head) ?? Self.default.head
        face = try c.decodeIfPresent(String.self, forKey: .face) ?? Self.default.face
        outfit = try c.decodeIfPresent(String.self, forKey: .outfit) ?? Self.default.outfit
        aura = try c.decodeIfPresent(String.self, forKey: .aura) ?? Self.default.aura
        pose = try c.decodeIfPresent(String.self, forKey: .pose) ?? Self.default.pose
        bodyHex = OwnedCosmetics.normalizedHex(try c.decodeIfPresent(String.self, forKey: .bodyHex) ?? Self.defaultBodyHex) ?? Self.defaultBodyHex
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(head, forKey: .head)
        try c.encode(face, forKey: .face)
        try c.encode(outfit, forKey: .outfit)
        try c.encode(aura, forKey: .aura)
        try c.encode(pose, forKey: .pose)
        try c.encode(bodyHex, forKey: .bodyHex)
    }
}

struct OwnedCosmetics: Codable {
    var purchasedIDs: Set<String>
    var equippedTitle: String
    var equippedBoardTheme: String
    var equippedTileTheme: String
    var equippedCardTheme: String
    var equippedNumberFont: String
    var equippedCellBorder: String
    var equippedAvatarHead: String
    var equippedAvatarFace: String
    var equippedAvatarOutfit: String
    var equippedAvatarAura: String
    var equippedAvatarPose: String
    var customAvatarBodyHex: String

    static let defaultPurchasedIDs: Set<String> = [
        "title_puzzler", "theme_classic", "tile_classic", "card_classic", "font_default", "border_default",
        "avatar_head_none", "avatar_face_smile", "avatar_outfit_basic", "avatar_aura_none", "avatar_pose_neutral", "avatar_pose_jump"
    ]

    static let `default` = OwnedCosmetics(
        purchasedIDs: defaultPurchasedIDs,
        equippedTitle: "title_puzzler",
        equippedBoardTheme: "theme_classic",
        equippedTileTheme: "tile_classic",
        equippedCardTheme: "card_classic",
        equippedNumberFont: "font_default",
        equippedCellBorder: "border_default",
        equippedAvatarHead: AvatarStyle.default.head,
        equippedAvatarFace: AvatarStyle.default.face,
        equippedAvatarOutfit: AvatarStyle.default.outfit,
        equippedAvatarAura: AvatarStyle.default.aura,
        equippedAvatarPose: AvatarStyle.default.pose,
        customAvatarBodyHex: AvatarStyle.defaultBodyHex
    )

    var avatarStyle: AvatarStyle {
        AvatarStyle(
            head: equippedAvatarHead,
            face: equippedAvatarFace,
            outfit: equippedAvatarOutfit,
            aura: equippedAvatarAura,
            pose: equippedAvatarPose,
            bodyHex: customAvatarBodyHex
        )
    }

    enum CodingKeys: String, CodingKey {
        case purchasedIDs, equippedTitle, equippedBoardTheme, equippedTileTheme, equippedNumberFont, equippedCellBorder
        case equippedCardTheme
        case equippedAvatarHead, equippedAvatarFace, equippedAvatarOutfit, equippedAvatarAura, equippedAvatarPose, customAvatarBodyHex
    }

    init(
        purchasedIDs: Set<String>,
        equippedTitle: String,
        equippedBoardTheme: String,
        equippedTileTheme: String = "tile_classic",
        equippedCardTheme: String = "card_classic",
        equippedNumberFont: String,
        equippedCellBorder: String,
        equippedAvatarHead: String,
        equippedAvatarFace: String,
        equippedAvatarOutfit: String,
        equippedAvatarAura: String,
        equippedAvatarPose: String,
        customAvatarBodyHex: String = AvatarStyle.defaultBodyHex
    ) {
        self.purchasedIDs = purchasedIDs.union(Self.defaultPurchasedIDs)
        self.equippedTitle = equippedTitle
        self.equippedBoardTheme = equippedBoardTheme
        self.equippedTileTheme = equippedTileTheme
        self.equippedCardTheme = equippedCardTheme
        self.equippedNumberFont = equippedNumberFont
        self.equippedCellBorder = equippedCellBorder
        self.equippedAvatarHead = equippedAvatarHead
        self.equippedAvatarFace = equippedAvatarFace
        self.equippedAvatarOutfit = equippedAvatarOutfit
        self.equippedAvatarAura = equippedAvatarAura
        self.equippedAvatarPose = equippedAvatarPose
        self.customAvatarBodyHex = Self.normalizedHex(customAvatarBodyHex) ?? AvatarStyle.defaultBodyHex
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.default
        purchasedIDs = (try c.decodeIfPresent(Set<String>.self, forKey: .purchasedIDs) ?? defaults.purchasedIDs).union(Self.defaultPurchasedIDs)
        equippedTitle = try c.decodeIfPresent(String.self, forKey: .equippedTitle) ?? defaults.equippedTitle
        equippedBoardTheme = try c.decodeIfPresent(String.self, forKey: .equippedBoardTheme) ?? defaults.equippedBoardTheme
        equippedTileTheme = try c.decodeIfPresent(String.self, forKey: .equippedTileTheme) ?? defaults.equippedTileTheme
        equippedCardTheme = try c.decodeIfPresent(String.self, forKey: .equippedCardTheme) ?? defaults.equippedCardTheme
        equippedNumberFont = try c.decodeIfPresent(String.self, forKey: .equippedNumberFont) ?? defaults.equippedNumberFont
        equippedCellBorder = try c.decodeIfPresent(String.self, forKey: .equippedCellBorder) ?? defaults.equippedCellBorder
        equippedAvatarHead = try c.decodeIfPresent(String.self, forKey: .equippedAvatarHead) ?? defaults.equippedAvatarHead
        equippedAvatarFace = try c.decodeIfPresent(String.self, forKey: .equippedAvatarFace) ?? defaults.equippedAvatarFace
        equippedAvatarOutfit = try c.decodeIfPresent(String.self, forKey: .equippedAvatarOutfit) ?? defaults.equippedAvatarOutfit
        equippedAvatarAura = try c.decodeIfPresent(String.self, forKey: .equippedAvatarAura) ?? defaults.equippedAvatarAura
        equippedAvatarPose = try c.decodeIfPresent(String.self, forKey: .equippedAvatarPose) ?? defaults.equippedAvatarPose
        customAvatarBodyHex = Self.normalizedHex(try c.decodeIfPresent(String.self, forKey: .customAvatarBodyHex) ?? defaults.customAvatarBodyHex) ?? defaults.customAvatarBodyHex
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(purchasedIDs, forKey: .purchasedIDs)
        try c.encode(equippedTitle, forKey: .equippedTitle)
        try c.encode(equippedBoardTheme, forKey: .equippedBoardTheme)
        try c.encode(equippedTileTheme, forKey: .equippedTileTheme)
        try c.encode(equippedCardTheme, forKey: .equippedCardTheme)
        try c.encode(equippedNumberFont, forKey: .equippedNumberFont)
        try c.encode(equippedCellBorder, forKey: .equippedCellBorder)
        try c.encode(equippedAvatarHead, forKey: .equippedAvatarHead)
        try c.encode(equippedAvatarFace, forKey: .equippedAvatarFace)
        try c.encode(equippedAvatarOutfit, forKey: .equippedAvatarOutfit)
        try c.encode(equippedAvatarAura, forKey: .equippedAvatarAura)
        try c.encode(equippedAvatarPose, forKey: .equippedAvatarPose)
        try c.encode(customAvatarBodyHex, forKey: .customAvatarBodyHex)
    }


    mutating func setCustomAvatarBodyHex(_ hex: String) -> Bool {
        guard let normalized = Self.normalizedHex(hex) else { return false }
        customAvatarBodyHex = normalized
        equippedAvatarOutfit = "avatar_outfit_basic"
        purchasedIDs.insert("avatar_outfit_basic")
        return true
    }

    static func normalizedHex(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard hex.count == 6,
              hex.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789ABCDEFabcdef").contains($0) }) else { return nil }
        return hex.uppercased()
    }

    mutating func equip(_ item: CosmeticItem) {
        purchasedIDs.insert(item.id)
        switch item.category {
        case .title:        equippedTitle = item.id
        case .boardTheme:   equippedBoardTheme = item.id
        case .tileTheme:    equippedTileTheme = item.id
        case .cardTheme:    equippedCardTheme = item.id
        case .numberFont:   equippedNumberFont = item.id
        case .cellBorder:   equippedCellBorder = item.id
        case .avatarHead:   equippedAvatarHead = item.id
        case .avatarFace:   equippedAvatarFace = item.id
        case .avatarOutfit: equippedAvatarOutfit = item.id
        case .avatarAura:   equippedAvatarAura = item.id
        case .avatarPose:   equippedAvatarPose = item.id
        }
    }
}


// MARK: - Daily rotation

struct DailyRotation {
    static let dailySlots = 4

    // Deterministic daily shuffle using day-of-epoch as seed (LCG).
    static func todaysTitles() -> [CosmeticItem] {
        availableItems(for: .title, ownedIDs: [])
    }

    static func todaysAvatarShopItems(ownedIDs: Set<String>) -> [CosmeticItem] {
        availableItems(for: [.avatarHead, .avatarFace, .avatarOutfit, .avatarAura], ownedIDs: ownedIDs, key: "avatar_shop")
    }

    static func todaysThemeShopItems(ownedIDs: Set<String>) -> [CosmeticItem] {
        availableItems(for: [.boardTheme, .tileTheme], ownedIDs: ownedIDs, key: "theme_shop")
    }

    static func availableItems(for category: CosmeticCategory, ownedIDs: Set<String>) -> [CosmeticItem] {
        let day = Int(Date().timeIntervalSince1970 / 86400)
        let pool = catalogItems(for: category).filter { item in
            item.price > 0 && item.isLaunchCatalogVisible && !ownedIDs.contains(item.id)
        }
        guard !pool.isEmpty else { return [] }

        let premiumRoll = abs(seed(day: day, category: category, slot: 42)) % 100
        let premiumRarity: CosmeticRarity = {
            switch premiumRoll {
            case 0..<60: return .rare
            case 60..<85: return .epic
            default: return .legendary
            }
        }()

        var selected: [CosmeticItem] = []
        appendRotatedSlot(.common, from: pool, into: &selected, day: day, category: category, slot: 0)
        appendRotatedSlot(.common, from: pool, into: &selected, day: day, category: category, slot: 1)
        appendRotatedSlot(.rare, from: pool, into: &selected, day: day, category: category, slot: 2)
        appendRotatedSlot(premiumRarity, from: pool, into: &selected, day: day, category: category, slot: 3)

        if selected.count < dailySlots {
            let fallback = seededShuffle(pool, seed: seed(day: day, category: category, slot: 99))
            for item in fallback where !selected.contains(where: { $0.id == item.id }) {
                selected.append(item)
                if selected.count == dailySlots { break }
            }
        }

        return selected.sorted { lhs, rhs in
            if lhs.rarity != rhs.rarity { return rarityRank(lhs.rarity) < rarityRank(rhs.rarity) }
            if lhs.price != rhs.price { return lhs.price < rhs.price }
            return lhs.name < rhs.name
        }
    }

    static func availableItems(for categories: [CosmeticCategory], ownedIDs: Set<String>, key: String) -> [CosmeticItem] {
        let day = Int(Date().timeIntervalSince1970 / 86400)
        let pool = categories.flatMap { catalogItems(for: $0) }.filter { item in
            item.price > 0 && item.isLaunchCatalogVisible && !ownedIDs.contains(item.id)
        }
        guard !pool.isEmpty else { return [] }

        var selected: [CosmeticItem] = []
        appendRotatedSlot(.common, from: pool, into: &selected, seed: seed(day: day, key: key, slot: 0))
        appendRotatedSlot(.rare, from: pool, into: &selected, seed: seed(day: day, key: key, slot: 1))
        appendRotatedSlot(.epic, from: pool, into: &selected, seed: seed(day: day, key: key, slot: 2))
        appendRotatedSlot(.legendary, from: pool, into: &selected, seed: seed(day: day, key: key, slot: 3))

        if selected.count < dailySlots {
            let fallback = seededShuffle(pool, seed: seed(day: day, key: key, slot: 99))
            for item in fallback where !selected.contains(where: { $0.id == item.id }) {
                selected.append(item)
                if selected.count == dailySlots { break }
            }
        }

        return selected.sorted { lhs, rhs in
            if lhs.category != rhs.category { return lhs.category.rawValue < rhs.category.rawValue }
            if lhs.rarity != rhs.rarity { return rarityRank(lhs.rarity) < rarityRank(rhs.rarity) }
            if lhs.price != rhs.price { return lhs.price < rhs.price }
            return lhs.name < rhs.name
        }
    }

    static var nextRotationDate: Date {
        let day = Int(Date().timeIntervalSince1970 / 86400)
        return Date(timeIntervalSince1970: Double(day + 1) * 86400)
    }

    private static func appendRotatedSlot(
        _ preferredRarity: CosmeticRarity,
        from pool: [CosmeticItem],
        into selected: inout [CosmeticItem],
        day: Int,
        category: CosmeticCategory,
        slot: Int
    ) {
        let rarityOrder = nearbyRarities(for: preferredRarity)
        for rarity in rarityOrder {
            let candidates = pool.filter { item in
                item.rarity == rarity && !selected.contains(where: { $0.id == item.id })
            }
            guard !candidates.isEmpty else { continue }
            if let item = seededShuffle(candidates, seed: seed(day: day, category: category, slot: slot)).first {
                selected.append(item)
                return
            }
        }
    }

    private static func appendRotatedSlot(
        _ preferredRarity: CosmeticRarity,
        from pool: [CosmeticItem],
        into selected: inout [CosmeticItem],
        seed: Int
    ) {
        let rarityOrder = nearbyRarities(for: preferredRarity)
        for rarity in rarityOrder {
            let candidates = pool.filter { item in
                item.rarity == rarity && !selected.contains(where: { $0.id == item.id })
            }
            guard !candidates.isEmpty else { continue }
            if let item = seededShuffle(candidates, seed: seed).first {
                selected.append(item)
                return
            }
        }
    }

    private static func nearbyRarities(for rarity: CosmeticRarity) -> [CosmeticRarity] {
        switch rarity {
        case .free: return [.common, .rare, .epic, .legendary]
        case .common: return [.common, .rare, .epic, .legendary]
        case .rare: return [.rare, .epic, .common, .legendary]
        case .epic: return [.epic, .legendary, .rare, .common]
        case .legendary: return [.legendary, .epic, .rare, .common]
        }
    }

    private static func rarityRank(_ rarity: CosmeticRarity) -> Int {
        switch rarity {
        case .free: return 0
        case .common: return 1
        case .rare: return 2
        case .epic: return 3
        case .legendary: return 4
        }
    }

    private static func catalogItems(for category: CosmeticCategory) -> [CosmeticItem] {
        switch category {
        case .title: return CosmeticCatalog.allTitles
        case .boardTheme: return CosmeticCatalog.boardThemes
        case .tileTheme: return CosmeticCatalog.tileThemes
        case .cardTheme: return CosmeticCatalog.cardThemes
        case .numberFont: return CosmeticCatalog.numberFonts
        case .cellBorder: return CosmeticCatalog.cellBorders
        case .avatarHead: return CosmeticCatalog.avatarHeads
        case .avatarFace: return CosmeticCatalog.launchAvatarFaces
        case .avatarOutfit: return CosmeticCatalog.avatarOutfits
        case .avatarAura: return CosmeticCatalog.avatarAuras
        case .avatarPose: return CosmeticCatalog.avatarPoses
        }
    }

    private static func seed(day: Int, category: CosmeticCategory, slot: Int) -> Int {
        var value = day &* 1_103 &+ slot &* 97
        for scalar in category.rawValue.unicodeScalars {
            value = value &* 31 &+ Int(scalar.value)
        }
        return value
    }

    private static func seed(day: Int, key: String, slot: Int) -> Int {
        var value = day &* 1_103 &+ slot &* 97
        for scalar in key.unicodeScalars {
            value = value &* 31 &+ Int(scalar.value)
        }
        return value
    }

    private static func seededShuffle<T>(_ array: [T], seed: Int) -> [T] {
        var result = array
        var s = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        for i in stride(from: result.count - 1, through: 1, by: -1) {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            let j = Int(s >> 33) % (i + 1)
            result.swapAt(i, j)
        }
        return result
    }
}

// MARK: - Catalog

struct CosmeticCatalog {
    static let all: [CosmeticItem] = allTitles + boardThemes + tileThemes + cardThemes + avatarHeads + avatarFaces + avatarOutfits + avatarAuras
    static let launchHeadIDs: Set<String> = [
        "avatar_head_party_hat",
        "avatar_head_headphones",
        "avatar_head_pixel_cap",
        "avatar_head_prize_ribbon",
        "avatar_head_neon_visor",
        "avatar_head_wizard",
        "avatar_head_crown",
        "avatar_head_lightning",
        "avatar_head_puzzle_crown",
        "avatar_head_halo",
        "avatar_head_cosmic_halo"
    ]
    static let launchExpressionIDs: Set<String> = [
        "avatar_face_smile",
        "avatar_face_wink",
        "avatar_face_laugh",
        "avatar_face_determined",
        "avatar_face_shades",
        "avatar_face_star",
        "avatar_face_lava",
        "avatar_face_heart",
        "avatar_face_rainbow"
    ]
    static let launchBodyIDs: Set<String> = [
        "avatar_outfit_basic",
        "avatar_outfit_hoodie",
        "avatar_outfit_frost",
        "avatar_outfit_candy",
        "avatar_outfit_lava",
        "avatar_outfit_prism",
        "avatar_outfit_armor",
        "avatar_outfit_royal_velvet",
        "avatar_outfit_starlight",
        "avatar_outfit_obsidian"
    ]
    static let launchAuraIDs: Set<String> = [
        "avatar_aura_teal",
        "avatar_aura_pink",
        "avatar_aura_lava",
        "avatar_aura_pixel",
        "avatar_aura_star",
        "avatar_aura_crown",
        "avatar_aura_storm",
        "avatar_aura_cosmic"
    ]
    static var launchAvatarFaces: [CosmeticItem] {
        avatarFaces.filter { launchExpressionIDs.contains($0.id) }
    }

    // Full title pool — only `dailySlots` of the paid ones appear in the shop each day
    static let allTitles: [CosmeticItem] = [
        CosmeticItem(id: "title_puzzler",      name: "Puzzler",           category: .title, price: 0,    previewImageName: "", description: "Your default title."),
        CosmeticItem(id: "title_mind_master",  name: "Mind Master",       category: .title, price: 300,  previewImageName: "", description: "For those who bend logic to their will."),
        CosmeticItem(id: "title_calculator",   name: "The Calculator",    category: .title, price: 300,  previewImageName: "", description: "Cold. Precise. Unstoppable."),
        CosmeticItem(id: "title_void_walker",  name: "Void Walker",       category: .title, price: 400,  previewImageName: "", description: "Navigates the grid from the dark between cells."),
        CosmeticItem(id: "title_grid_reaper",  name: "Grid Reaper",       category: .title, price: 400,  previewImageName: "", description: "Leaves no empty cell behind."),
        CosmeticItem(id: "title_number_god",   name: "Number God",        category: .title, price: 600,  previewImageName: "", description: "Digits bow before them."),
        CosmeticItem(id: "title_logic_lord",   name: "Logic Lord",        category: .title, price: 500,  previewImageName: "", description: "Reason incarnate."),
        CosmeticItem(id: "title_phantom",      name: "The Phantom",       category: .title, price: 350,  previewImageName: "", description: "Solves before you blink."),
        CosmeticItem(id: "title_grandmaster",  name: "Grand Master",      category: .title, price: 1_800, previewImageName: "", description: "Earned at the summit."),
        CosmeticItem(id: "title_oracle",       name: "The Oracle",        category: .title, price: 500,  previewImageName: "", description: "Sees the solution before it's placed."),
        CosmeticItem(id: "title_iron_mind",    name: "Iron Mind",         category: .title, price: 350,  previewImageName: "", description: "Unshakeable under pressure."),
        CosmeticItem(id: "title_cascade",      name: "Cascade",           category: .title, price: 400,  previewImageName: "", description: "Solutions flow like water."),
        CosmeticItem(id: "title_sigma",        name: "Sigma",             category: .title, price: 300,  previewImageName: "", description: "Sum of all puzzles."),
        CosmeticItem(id: "title_apex",         name: "Apex",              category: .title, price: 600,  previewImageName: "", description: "There is no higher rank."),
        CosmeticItem(id: "title_ghost",        name: "Ghost",             category: .title, price: 350,  previewImageName: "", description: "Here, then gone."),
        CosmeticItem(id: "title_anomaly",      name: "Anomaly",           category: .title, price: 400,  previewImageName: "", description: "Defies all expected patterns."),
        CosmeticItem(id: "title_overlord",     name: "Overlord",          category: .title, price: 1_200, previewImageName: "", description: "Commands the board."),
        CosmeticItem(id: "title_cipher",       name: "Cipher",            category: .title, price: 300,  previewImageName: "", description: "Every grid is just another code."),
        CosmeticItem(id: "title_theorem",      name: "Living Theorem",    category: .title, price: 450,  previewImageName: "", description: "Proven. Irrefutable."),
        CosmeticItem(id: "title_nexus",        name: "Nexus",             category: .title, price: 450,  previewImageName: "", description: "Where all solutions converge."),
        CosmeticItem(id: "title_swift",        name: "Swift",             category: .title, price: 300,  previewImageName: "", description: "Speed is the only metric."),
        CosmeticItem(id: "title_eternal",      name: "The Eternal",       category: .title, price: 1_500, previewImageName: "", description: "Has been solving since before the grid existed."),
        CosmeticItem(id: "title_obsidian",     name: "Obsidian",          category: .title, price: 500,  previewImageName: "", description: "Hard and flawless."),
        CosmeticItem(id: "title_zero",         name: "Zero Error",        category: .title, price: 600,  previewImageName: "", description: "Not one mistake. Ever."),
        CosmeticItem(id: "title_path_finder",  name: "Path Finder",       category: .title, price: 250,  previewImageName: "", description: "Always sees the route through the board."),
        CosmeticItem(id: "title_grid_runner",  name: "Grid Runner",       category: .title, price: 300,  previewImageName: "", description: "Fast feet across every puzzle lane."),
        CosmeticItem(id: "title_puzzle_pilot", name: "Puzzle Pilot",      category: .title, price: 350,  previewImageName: "", description: "Flies through tricky patterns."),
        CosmeticItem(id: "title_combo_crafter", name: "Combo Crafter",    category: .title, price: 450,  previewImageName: "", description: "Turns small moves into big chains."),
        CosmeticItem(id: "title_quick_thinker", name: "Quick Thinker",    category: .title, price: 400,  previewImageName: "", description: "Decides before the timer blinks."),
        CosmeticItem(id: "title_board_bender", name: "Board Bender",      category: .title, price: 550,  previewImageName: "", description: "Makes the board move their way."),
        CosmeticItem(id: "title_letter_lynx",  name: "Letter Lynx",       category: .title, price: 500,  previewImageName: "", description: "Quick eyes for hidden words."),
        CosmeticItem(id: "title_pattern_chaser", name: "Pattern Chaser",  category: .title, price: 650,  previewImageName: "", description: "Tracks every clue in motion."),
        CosmeticItem(id: "title_neon_solver", name: "Neon Solver",       category: .title, price: 1_200, previewImageName: "", description: "Bright moves under arcade lights."),
        CosmeticItem(id: "title_color_captain", name: "Color Captain",   category: .title, price: 1_350, previewImageName: "", description: "Commands paths, links, and color flow."),
        CosmeticItem(id: "title_mine_dodger", name: "Mine Dodger",       category: .title, price: 1_250, previewImageName: "", description: "Somehow always steps safely."),
        CosmeticItem(id: "title_wordsmith",   name: "Wordsmith",         category: .title, price: 1_450, previewImageName: "", description: "Turns letters into pressure."),
        CosmeticItem(id: "title_grid_architect", name: "Grid Architect", category: .title, price: 1_700, previewImageName: "", description: "Builds clean wins from chaos."),
        CosmeticItem(id: "title_lava_legend", name: "Lava Legend",       category: .title, price: 1_900, previewImageName: "", description: "Keeps cool when the arena heats up."),
        CosmeticItem(id: "title_crown_strategist", name: "Crown Strategist", category: .title, price: 2_600, previewImageName: "", description: "Every move has royal intent."),
        CosmeticItem(id: "title_final_piece", name: "The Final Piece",   category: .title, price: 3_000, previewImageName: "", description: "The one piece every win needs."),
        CosmeticItem(id: "title_arcade_oracle", name: "Arcade Oracle",   category: .title, price: 3_200, previewImageName: "", description: "Reads the arena before it happens."),
        CosmeticItem(id: "title_puzzle_royalty", name: "Puzzle Royalty", category: .title, price: 3_500, previewImageName: "", description: "A title with crown-level presence."),
        CosmeticItem(id: "title_untouchable", name: "Untouchable",       category: .title, price: 4_000, previewImageName: "", description: "Good luck catching this score."),
        CosmeticItem(id: "title_daily_spark", name: "Daily Spark",       category: .title, price: 300,  previewImageName: "", description: "Shows up, plays today, keeps the glow alive."),
        CosmeticItem(id: "title_streak_starter", name: "Streak Starter", category: .title, price: 350,  previewImageName: "", description: "The first day of something bigger."),
        CosmeticItem(id: "title_tile_tamer", name: "Tile Tamer",         category: .title, price: 450,  previewImageName: "", description: "Keeps every tile under control."),
        CosmeticItem(id: "title_lobby_legend", name: "Lobby Legend",     category: .title, price: 650,  previewImageName: "", description: "Everyone notices when they join."),
        CosmeticItem(id: "title_stage_star", name: "Stage Star",         category: .title, price: 1_200, previewImageName: "", description: "Built for party-room spotlight moments."),
        CosmeticItem(id: "title_prism_mind", name: "Prism Mind",         category: .title, price: 1_350, previewImageName: "", description: "Sees every angle at once."),
        CosmeticItem(id: "title_rare_find", name: "Rare Find",           category: .title, price: 1_300, previewImageName: "", description: "A clean pull from the prize pool."),
        CosmeticItem(id: "title_combo_king", name: "Combo King",         category: .title, price: 1_800, previewImageName: "", description: "Stacks smart moves into big wins."),
        CosmeticItem(id: "title_crown_piece", name: "Crown Piece",       category: .title, price: 3_200, previewImageName: "", description: "A royal fit for the final slot."),
        CosmeticItem(id: "title_party_champion", name: "Party Champion", category: .title, price: 4_000, previewImageName: "", description: "Tops the room when the last round ends."),
    ]

    static let boardThemes: [CosmeticItem] = [
        CosmeticItem(id: "theme_classic",    name: "Classic",     category: .boardTheme, price: 0,    previewImageName: "theme_classic",    description: "The default clean look."),
        CosmeticItem(id: "theme_dark",       name: "Dark Mode",   category: .boardTheme, price: 200,  previewImageName: "theme_dark",       description: "Sleek dark panels for focused puzzle runs."),
        CosmeticItem(id: "theme_color_link", name: "Color Link",  category: .boardTheme, price: 700,  previewImageName: "theme_color_link", description: "Teal, pink, and blue path energy."),
        CosmeticItem(id: "theme_grid_duel",  name: "Card Table",  category: .boardTheme, price: 700,  previewImageName: "theme_grid_duel",  description: "Gold and blue tabletop shine."),
        CosmeticItem(id: "theme_lava_rescue", name: "Lava Rescue", category: .boardTheme, price: 1_200, previewImageName: "theme_lava_rescue", description: "Molten orange pressure with crown-gold heat."),
        CosmeticItem(id: "theme_prism_party", name: "Prism Party", category: .boardTheme, price: 2_200, previewImageName: "theme_prism_party", description: "A vivid mix of pink, teal, purple, and gold."),
        CosmeticItem(id: "theme_cosmic_crown", name: "Cosmic Crown", category: .boardTheme, price: 3_200, previewImageName: "theme_cosmic_crown", description: "Legendary deep-space blue with gold shine."),
    ]

    static let tileThemes: [CosmeticItem] = [
        CosmeticItem(id: "tile_classic", name: "Classic Tiles", category: .tileTheme, price: 0, previewImageName: "tile_classic", description: "Clean default puzzle tiles."),
        CosmeticItem(id: "tile_neon_pop", name: "Neon Pop", category: .tileTheme, price: 550, previewImageName: "tile_neon_pop", description: "Bright pink and purple arcade tiles."),
        CosmeticItem(id: "tile_mint_glass", name: "Mint Glass", category: .tileTheme, price: 700, previewImageName: "tile_mint_glass", description: "Cool mint tiles with a glassy glow."),
        CosmeticItem(id: "tile_lava_core", name: "Lava Core", category: .tileTheme, price: 1_250, previewImageName: "tile_lava_core", description: "Hot lava tiles for high-pressure games."),
        CosmeticItem(id: "tile_crown_gold", name: "Crown Gold", category: .tileTheme, price: 1_900, previewImageName: "tile_crown_gold", description: "Gold tiles inspired by the Puzzle Party crown."),
        CosmeticItem(id: "tile_starlight", name: "Starlight", category: .tileTheme, price: 1_100, previewImageName: "tile_starlight", description: "Night-sky tiles with icy highlights."),
        CosmeticItem(id: "tile_prism_pop", name: "Prism Pop", category: .tileTheme, price: 1_400, previewImageName: "tile_prism_pop", description: "Pink, teal, and purple arcade prisms."),
        CosmeticItem(id: "tile_crystal", name: "Crystal", category: .tileTheme, price: 1_700, previewImageName: "tile_crystal", description: "Clear teal crystal tiles with sharp polish."),
        CosmeticItem(id: "tile_cosmic", name: "Cosmic", category: .tileTheme, price: 2_600, previewImageName: "tile_cosmic", description: "Legendary space-black tiles with gold edges."),
    ]

    static let cardThemes: [CosmeticItem] = [
        CosmeticItem(id: "card_classic", name: "Classic Cards", category: .cardTheme, price: 0, previewImageName: "card_classic", description: "Clean red and blue playing cards."),
        CosmeticItem(id: "card_crown_casino", name: "Crown Casino", category: .cardTheme, price: 800, previewImageName: "card_crown_casino", description: "Blue-and-gold cards with a crown back."),
        CosmeticItem(id: "card_arcade_pink", name: "Arcade Pink", category: .cardTheme, price: 1_100, previewImageName: "card_arcade_pink", description: "Hot-pink arcade cards with teal shine."),
        CosmeticItem(id: "card_royal_blue", name: "Royal Blue", category: .cardTheme, price: 1_600, previewImageName: "card_royal_blue", description: "Polished blue cards with bright icy edges."),
        CosmeticItem(id: "card_cosmic_gold", name: "Cosmic Gold", category: .cardTheme, price: 2_800, previewImageName: "card_cosmic_gold", description: "Legendary space-black backs with gold stars.")
    ]

    static let numberFonts: [CosmeticItem] = [
        CosmeticItem(id: "font_default",    name: "Default",      category: .numberFont, price: 0,   previewImageName: "font_default",   description: "Clean system font."),
        CosmeticItem(id: "font_pixel",      name: "Pixel",        category: .numberFont, price: 250, previewImageName: "font_pixel",     description: "Retro pixel-art digits."),
        CosmeticItem(id: "font_bold",       name: "Bold Impact",  category: .numberFont, price: 150, previewImageName: "font_bold",      description: "Heavy weight, impossible to miss."),
        CosmeticItem(id: "font_elegant",    name: "Elegant",      category: .numberFont, price: 300, previewImageName: "font_elegant",   description: "Thin serif numbers."),
    ]

    static let cellBorders: [CosmeticItem] = [
        CosmeticItem(id: "border_default",  name: "Default",      category: .cellBorder, price: 0,   previewImageName: "border_default",  description: "Standard thin border."),
        CosmeticItem(id: "border_rounded",  name: "Rounded",      category: .cellBorder, price: 100, previewImageName: "border_rounded",  description: "Soft rounded cell corners."),
        CosmeticItem(id: "border_glow",     name: "Glow",         category: .cellBorder, price: 400, previewImageName: "border_glow",     description: "Selected cells emit a soft glow."),
        CosmeticItem(id: "border_dash",     name: "Dashed",       category: .cellBorder, price: 200, previewImageName: "border_dash",     description: "Dashed borders for a sketch feel."),
    ]

    static let avatarHeads: [CosmeticItem] = [
        CosmeticItem(id: "avatar_head_none",       name: "Clean",          category: .avatarHead, price: 0,     previewImageName: "", description: "Classic puzzle-piece look."),
        CosmeticItem(id: "avatar_head_crown",      name: "Champion Crown", category: .avatarHead, price: 1_200, previewImageName: "", description: "A clean gold crown with a pink champion gem."),
        CosmeticItem(id: "avatar_head_headphones", name: "Headphones",     category: .avatarHead, price: 700,   previewImageName: "", description: "Locked-in puzzle focus."),
        CosmeticItem(id: "avatar_head_wizard",     name: "Wizard Hat",     category: .avatarHead, price: 1_500, previewImageName: "", description: "For strange grid magic."),
        CosmeticItem(id: "avatar_head_lightning",  name: "Lightning Hair", category: .avatarHead, price: 2_500, previewImageName: "", description: "Fast solve energy."),
        CosmeticItem(id: "avatar_head_halo",       name: "Golden Halo",    category: .avatarHead, price: 4_000, previewImageName: "", description: "Legendary warm halo light."),
        CosmeticItem(id: "avatar_head_puzzle_crown", name: "Flame Crown", category: .avatarHead, price: 2_800, previewImageName: "", description: "Living amber flames above a golden band."),
        CosmeticItem(id: "avatar_head_neon_visor", name: "Neon Visor", category: .avatarHead, price: 1_300, previewImageName: "", description: "A bright visor for fast reads."),
        CosmeticItem(id: "avatar_head_star_clip", name: "Star Clip", category: .avatarHead, price: 1_200, previewImageName: "", description: "An animated star clip with bright arcade twinkle."),
        CosmeticItem(id: "avatar_head_lava_helmet", name: "Lava Helmet", category: .avatarHead, price: 2_600, previewImageName: "", description: "Heat-proof gear for rescue runs."),
        CosmeticItem(id: "avatar_head_pixel_cap", name: "Arcade Cap", category: .avatarHead, price: 850, previewImageName: "", description: "A clean retro cap with pixel-panel shine."),
        CosmeticItem(id: "avatar_head_mini_crown", name: "Gold Charm", category: .avatarHead, price: 500, previewImageName: "", description: "A small crown charm clipped to the side."),
        CosmeticItem(id: "avatar_head_party_hat", name: "Party Hat", category: .avatarHead, price: 450, previewImageName: "", description: "A bright hat for lobby wins."),
        CosmeticItem(id: "avatar_head_bubble_crown", name: "Bubble Tiara", category: .avatarHead, price: 650, previewImageName: "", description: "A soft glossy tiara with playful shine."),
        CosmeticItem(id: "avatar_head_arcade_antenna", name: "Arcade Antenna", category: .avatarHead, price: 900, previewImageName: "", description: "Tiny arcade signal for fast matchups."),
        CosmeticItem(id: "avatar_head_prize_ribbon", name: "Top Hat", category: .avatarHead, price: 1_100, previewImageName: "", description: "A clean party top hat with crown-gold trim."),
        CosmeticItem(id: "avatar_head_royal_headband", name: "Royal Headband", category: .avatarHead, price: 1_400, previewImageName: "", description: "Pink-and-gold headwear for ranked focus."),
        CosmeticItem(id: "avatar_head_crystal_spikes", name: "Crystal Spikes", category: .avatarHead, price: 1_700, previewImageName: "", description: "Bright crystal points with teal shine."),
        CosmeticItem(id: "avatar_head_gem_crown", name: "Gem Crown", category: .avatarHead, price: 2_200, previewImageName: "", description: "A jewel crown for epic pulls."),
        CosmeticItem(id: "avatar_head_cosmic_halo", name: "Orbit Halo", category: .avatarHead, price: 3_200, previewImageName: "", description: "Legendary deep-space orbit light.")
    ]

    static let avatarFaces: [CosmeticItem] = [
        CosmeticItem(id: "avatar_face_smile",   name: "Smile",    category: .avatarFace, price: 0,     previewImageName: "", description: "Friendly default expression."),
        CosmeticItem(id: "avatar_face_focused", name: "Focused",  category: .avatarFace, price: 500,   previewImageName: "", description: "Locked on the puzzle."),
        CosmeticItem(id: "avatar_face_wink",    name: "Wink",     category: .avatarFace, price: 700,   previewImageName: "", description: "A little postgame confidence."),
        CosmeticItem(id: "avatar_face_shades",  name: "Shades",   category: .avatarFace, price: 1_200, previewImageName: "", description: "Cool under ranked pressure."),
        CosmeticItem(id: "avatar_face_gem",     name: "Gem Eyes", category: .avatarFace, price: 2_000, previewImageName: "", description: "Icon-pink jewel intensity."),
        CosmeticItem(id: "avatar_face_laugh", name: "Laugh", category: .avatarFace, price: 450, previewImageName: "", description: "A cheerful post-win grin."),
        CosmeticItem(id: "avatar_face_determined", name: "Determined", category: .avatarFace, price: 800, previewImageName: "", description: "Locked in and ready."),
        CosmeticItem(id: "avatar_face_sleepy", name: "Sleepy", category: .avatarFace, price: 500, previewImageName: "", description: "Still solving, somehow."),
        CosmeticItem(id: "avatar_face_star", name: "Star Eyes", category: .avatarFace, price: 1_500, previewImageName: "", description: "Bright-eyed arcade energy."),
        CosmeticItem(id: "avatar_face_oops", name: "Oops", category: .avatarFace, price: 700, previewImageName: "", description: "For close calls and lucky saves."),
        CosmeticItem(id: "avatar_face_smirk", name: "Champion Smirk", category: .avatarFace, price: 2_200, previewImageName: "", description: "A confident little flex."),
        CosmeticItem(id: "avatar_face_blush", name: "Blush", category: .avatarFace, price: 650, previewImageName: "", description: "Soft cheeks for a friendly puzzle pal."),
        CosmeticItem(id: "avatar_face_pixel", name: "Pixel Smile", category: .avatarFace, price: 900, previewImageName: "", description: "Retro arcade pixels with a tiny grin."),
        CosmeticItem(id: "avatar_face_party", name: "Party Eyes", category: .avatarFace, price: 1_100, previewImageName: "", description: "Bright celebration eyes for social wins."),
        CosmeticItem(id: "avatar_face_robot", name: "Robot Eyes", category: .avatarFace, price: 1_300, previewImageName: "", description: "Clean digital focus."),
        CosmeticItem(id: "avatar_face_lava", name: "Lava Eyes", category: .avatarFace, price: 1_700, previewImageName: "", description: "Hot rescue-run intensity."),
        CosmeticItem(id: "avatar_face_crown", name: "Crown Eyes", category: .avatarFace, price: 2_600, previewImageName: "", description: "Legendary golden eye shine."),
        CosmeticItem(id: "avatar_face_masked", name: "Masked", category: .avatarFace, price: 1_400, previewImageName: "", description: "A mysterious puzzle-party mask."),
        CosmeticItem(id: "avatar_face_heart", name: "Heart Eyes", category: .avatarFace, price: 1_900, previewImageName: "", description: "Cute heart-eyed party energy."),
        CosmeticItem(id: "avatar_face_chill", name: "Chill", category: .avatarFace, price: 550, previewImageName: "", description: "Relaxed eyes for calm clears."),
        CosmeticItem(id: "avatar_face_prize", name: "Prize Smile", category: .avatarFace, price: 750, previewImageName: "", description: "A big smile for a fresh unlock."),
        CosmeticItem(id: "avatar_face_glitter", name: "Glitter Eyes", category: .avatarFace, price: 1_200, previewImageName: "", description: "Sparkly eyes for epic reveals."),
        CosmeticItem(id: "avatar_face_focus_laser", name: "Focus Laser", category: .avatarFace, price: 1_600, previewImageName: "", description: "Sharp neon focus under pressure."),
        CosmeticItem(id: "avatar_face_rainbow", name: "Rainbow Eyes", category: .avatarFace, price: 1_900, previewImageName: "", description: "Colorful party energy across both eyes."),
        CosmeticItem(id: "avatar_face_gold_smile", name: "Gold Smile", category: .avatarFace, price: 2_600, previewImageName: "", description: "Legendary golden confidence."),
        CosmeticItem(id: "avatar_face_cosmic", name: "Cosmic Eyes", category: .avatarFace, price: 2_800, previewImageName: "", description: "A tiny starfield stare.")
    ]

    static let avatarOutfits: [CosmeticItem] = [
        CosmeticItem(id: "avatar_outfit_basic", name: "Custom Solid", category: .avatarOutfit, price: 0,     previewImageName: "", description: "Pick any solid puzzle-piece color."),
        CosmeticItem(id: "avatar_outfit_hoodie", name: "Teal Piece",  category: .avatarOutfit, price: 900,   previewImageName: "", description: "Polished teal enamel with mint edge details."),
        CosmeticItem(id: "avatar_outfit_cape",   name: "Diamond Pink", category: .avatarOutfit, price: 1_400, previewImageName: "", description: "A glossy jewel-pink premium body."),
        CosmeticItem(id: "avatar_outfit_armor",  name: "Royal Blue",  category: .avatarOutfit, price: 2_400, previewImageName: "", description: "Blue armor panels with silver trim and a small shield."),
        CosmeticItem(id: "avatar_outfit_royal",  name: "Crown Gold", category: .avatarOutfit, price: 4_500, previewImageName: "", description: "Legendary crown-gold puzzle body."),
        CosmeticItem(id: "avatar_outfit_lava", name: "Lava Core", category: .avatarOutfit, price: 1_800, previewImageName: "", description: "Dark volcanic rock with glowing molten seams."),
        CosmeticItem(id: "avatar_outfit_frost", name: "Frost Piece", category: .avatarOutfit, price: 1_200, previewImageName: "", description: "Cool blue ice-gloss body."),
        CosmeticItem(id: "avatar_outfit_mint", name: "Mint Glow", category: .avatarOutfit, price: 900, previewImageName: "", description: "Soft mint with bright white trim."),
        CosmeticItem(id: "avatar_outfit_candy", name: "Candy Piece", category: .avatarOutfit, price: 1_600, previewImageName: "", description: "Glossy pink candy stripes with mint accents."),
        CosmeticItem(id: "avatar_outfit_obsidian", name: "Obsidian Piece", category: .avatarOutfit, price: 4_200, previewImageName: "", description: "Dark glass for legendary style."),
        CosmeticItem(id: "avatar_outfit_prism", name: "Prism Piece", category: .avatarOutfit, price: 2_200, previewImageName: "", description: "Epic prism colors across the puzzle body."),
        CosmeticItem(id: "avatar_outfit_crystal", name: "Crystal Piece", category: .avatarOutfit, price: 2_400, previewImageName: "", description: "Sharp glassy shine for epic unlocks."),
        CosmeticItem(id: "avatar_outfit_royal_velvet", name: "Royal Velvet", category: .avatarOutfit, price: 2_800, previewImageName: "", description: "Deep velvet with gold piping and a glinting jewel."),
        CosmeticItem(id: "avatar_outfit_starlight", name: "Starlight Piece", category: .avatarOutfit, price: 3_300, previewImageName: "", description: "Legendary night-sky puzzle body.")
    ]

    static let avatarAuras: [CosmeticItem] = [
        CosmeticItem(id: "avatar_aura_none",  name: "None",        category: .avatarAura, price: 0,     previewImageName: "", description: "No aura equipped."),
        CosmeticItem(id: "avatar_aura_teal",  name: "Teal Glow",   category: .avatarAura, price: 900,   previewImageName: "", description: "Soft Color Link energy."),
        CosmeticItem(id: "avatar_aura_pink",  name: "Pink Spark",  category: .avatarAura, price: 1_200, previewImageName: "", description: "Hot-pink victory sparks."),
        CosmeticItem(id: "avatar_aura_crown", name: "Crown Shine", category: .avatarAura, price: 2_500, previewImageName: "", description: "Gold rank radiance."),
        CosmeticItem(id: "avatar_aura_storm", name: "Storm Cloud", category: .avatarAura, price: 4_000, previewImageName: "", description: "A legendary cloud aura with soft lightning and rain."),
        CosmeticItem(id: "avatar_aura_lava", name: "Lava Bubble", category: .avatarAura, price: 1_600, previewImageName: "", description: "Warm rescue-run bubbles."),
        CosmeticItem(id: "avatar_aura_star", name: "Star Burst", category: .avatarAura, price: 2_200, previewImageName: "", description: "A burst of tiny arcade stars."),
        CosmeticItem(id: "avatar_aura_pixel", name: "Pixel Ring", category: .avatarAura, price: 1_100, previewImageName: "", description: "Retro square energy."),
        CosmeticItem(id: "avatar_aura_confetti", name: "Confetti Pop", category: .avatarAura, price: 700, previewImageName: "", description: "Tiny party flecks around the piece."),
        CosmeticItem(id: "avatar_aura_stage_light", name: "Stage Light", category: .avatarAura, price: 1_100, previewImageName: "", description: "A spotlight for party-stage moments."),
        CosmeticItem(id: "avatar_aura_prism", name: "Prism Ring", category: .avatarAura, price: 1_700, previewImageName: "", description: "A bright multicolor aura loop."),
        CosmeticItem(id: "avatar_aura_crystal", name: "Crystal Shine", category: .avatarAura, price: 2_200, previewImageName: "", description: "Sharp teal-white crystalline shine."),
        CosmeticItem(id: "avatar_aura_gold_crown", name: "Gold Crown Aura", category: .avatarAura, price: 2_800, previewImageName: "", description: "Legendary crown-gold radiance."),
        CosmeticItem(id: "avatar_aura_cosmic", name: "Cosmic Aura", category: .avatarAura, price: 3_300, previewImageName: "", description: "Legendary deep-space glow.")
    ]

    static let avatarPoses: [CosmeticItem] = [
        CosmeticItem(id: "avatar_pose_neutral",  name: "Neutral",  category: .avatarPose, price: 0,     previewImageName: "", description: "A calm little puzzle-piece stance."),
        CosmeticItem(id: "avatar_pose_victory",  name: "Victory",  category: .avatarPose, price: 700,   previewImageName: "", description: "Both arms up after a win."),
        CosmeticItem(id: "avatar_pose_thinking", name: "Thinking", category: .avatarPose, price: 700,   previewImageName: "", description: "A puzzler's pause."),
        CosmeticItem(id: "avatar_pose_ready",    name: "Ready",    category: .avatarPose, price: 1_100, previewImageName: "", description: "A planted stance for ranked."),
        CosmeticItem(id: "avatar_pose_flex",     name: "Flex",     category: .avatarPose, price: 1_500, previewImageName: "", description: "For confident board clears."),
        CosmeticItem(id: "avatar_pose_point", name: "Point", category: .avatarPose, price: 600, previewImageName: "", description: "Points right at the winning move."),
        CosmeticItem(id: "avatar_pose_jump", name: "Jump", category: .avatarPose, price: 900, previewImageName: "", description: "A bouncy little victory pose."),
        CosmeticItem(id: "avatar_pose_celebrate", name: "Celebrate", category: .avatarPose, price: 1_300, previewImageName: "", description: "Big arena celebration energy."),
        CosmeticItem(id: "avatar_pose_sneaky", name: "Sneaky", category: .avatarPose, price: 1_000, previewImageName: "", description: "A quiet move before the win."),
        CosmeticItem(id: "avatar_pose_power", name: "Power Up", category: .avatarPose, price: 2_400, previewImageName: "", description: "Powered-up puzzle stance.")
    ]

}
