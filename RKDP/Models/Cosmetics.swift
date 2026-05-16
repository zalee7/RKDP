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
    case title       = "Titles"
    case boardTheme  = "Game Theme"
    case numberFont  = "Number Style"
    case cellBorder  = "Cell Border"
}

struct CosmeticItem: Identifiable, Codable {
    var id: String
    var name: String
    var category: CosmeticCategory
    var price: Int
    var previewImageName: String
    var description: String
}

struct OwnedCosmetics: Codable {
    var purchasedIDs: Set<String>
    var equippedTitle: String
    var equippedBoardTheme: String
    var equippedNumberFont: String
    var equippedCellBorder: String

    static let `default` = OwnedCosmetics(
        purchasedIDs: ["title_puzzler", "theme_classic", "font_default", "border_default"],
        equippedTitle: "title_puzzler",
        equippedBoardTheme: "theme_classic",
        equippedNumberFont: "font_default",
        equippedCellBorder: "border_default"
    )

    mutating func equip(_ item: CosmeticItem) {
        switch item.category {
        case .title:       equippedTitle = item.id
        case .boardTheme:  equippedBoardTheme = item.id
        case .numberFont:  equippedNumberFont = item.id
        case .cellBorder:  equippedCellBorder = item.id
        }
    }
}

// MARK: - Daily rotation

struct DailyRotation {
    static let dailySlots = 6

    // Deterministic daily shuffle using day-of-epoch as seed (LCG)
    static func todaysTitles() -> [CosmeticItem] {
        let day = Int(Date().timeIntervalSince1970 / 86400)
        let pool = CosmeticCatalog.allTitles.filter { $0.price > 0 }   // free title never rotates out
        return seededShuffle(pool, seed: day).prefix(dailySlots).map { $0 }
    }

    static var nextRotationDate: Date {
        let day = Int(Date().timeIntervalSince1970 / 86400)
        return Date(timeIntervalSince1970: Double(day + 1) * 86400)
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
    static let all: [CosmeticItem] = allTitles + boardThemes + numberFonts + cellBorders

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
        CosmeticItem(id: "title_grandmaster",  name: "Grand Master",      category: .title, price: 1200, previewImageName: "", description: "Earned at the summit."),
        CosmeticItem(id: "title_oracle",       name: "The Oracle",        category: .title, price: 500,  previewImageName: "", description: "Sees the solution before it's placed."),
        CosmeticItem(id: "title_iron_mind",    name: "Iron Mind",         category: .title, price: 350,  previewImageName: "", description: "Unshakeable under pressure."),
        CosmeticItem(id: "title_cascade",      name: "Cascade",           category: .title, price: 400,  previewImageName: "", description: "Solutions flow like water."),
        CosmeticItem(id: "title_sigma",        name: "Sigma",             category: .title, price: 300,  previewImageName: "", description: "Sum of all puzzles."),
        CosmeticItem(id: "title_apex",         name: "Apex",              category: .title, price: 600,  previewImageName: "", description: "There is no higher rank."),
        CosmeticItem(id: "title_ghost",        name: "Ghost",             category: .title, price: 350,  previewImageName: "", description: "Here, then gone."),
        CosmeticItem(id: "title_anomaly",      name: "Anomaly",           category: .title, price: 400,  previewImageName: "", description: "Defies all expected patterns."),
        CosmeticItem(id: "title_overlord",     name: "Overlord",          category: .title, price: 700,  previewImageName: "", description: "Commands the board."),
        CosmeticItem(id: "title_cipher",       name: "Cipher",            category: .title, price: 300,  previewImageName: "", description: "Every grid is just another code."),
        CosmeticItem(id: "title_theorem",      name: "Living Theorem",    category: .title, price: 450,  previewImageName: "", description: "Proven. Irrefutable."),
        CosmeticItem(id: "title_nexus",        name: "Nexus",             category: .title, price: 450,  previewImageName: "", description: "Where all solutions converge."),
        CosmeticItem(id: "title_swift",        name: "Swift",             category: .title, price: 300,  previewImageName: "", description: "Speed is the only metric."),
        CosmeticItem(id: "title_eternal",      name: "The Eternal",       category: .title, price: 800,  previewImageName: "", description: "Has been solving since before the grid existed."),
        CosmeticItem(id: "title_obsidian",     name: "Obsidian",          category: .title, price: 500,  previewImageName: "", description: "Hard and flawless."),
        CosmeticItem(id: "title_zero",         name: "Zero Error",        category: .title, price: 600,  previewImageName: "", description: "Not one mistake. Ever."),
    ]

    static let boardThemes: [CosmeticItem] = [
        CosmeticItem(id: "theme_classic",    name: "Classic",     category: .boardTheme, price: 0,    previewImageName: "theme_classic",    description: "The default clean look."),
        CosmeticItem(id: "theme_dark",       name: "Dark Mode",   category: .boardTheme, price: 200,  previewImageName: "theme_dark",       description: "Sleek dark panels for focused puzzle runs."),
        CosmeticItem(id: "theme_ocean",      name: "Ocean",       category: .boardTheme, price: 350,  previewImageName: "theme_ocean",      description: "Cool blues for calm grid solving."),
        CosmeticItem(id: "theme_forest",     name: "Forest",      category: .boardTheme, price: 350,  previewImageName: "theme_forest",     description: "Earthy greens for quiet board play."),
        CosmeticItem(id: "theme_neon",       name: "Neon",        category: .boardTheme, price: 600,  previewImageName: "theme_neon",       description: "Arcade glow for fast ranked matches."),
        CosmeticItem(id: "theme_gold",       name: "Gold Edition", category: .boardTheme, price: 1500, previewImageName: "theme_gold",       description: "Premium gold-leaf styling for top ranks."),
        CosmeticItem(id: "theme_color_link", name: "Color Link",  category: .boardTheme, price: 700,  previewImageName: "theme_color_link", description: "Teal, pink, and blue path energy."),
        CosmeticItem(id: "theme_grid_duel",  name: "Grid Duel",   category: .boardTheme, price: 700,  previewImageName: "theme_grid_duel",  description: "Gold and blue symmetry-board shine."),
        CosmeticItem(id: "theme_word_neon",  name: "Word Neon",   category: .boardTheme, price: 650,  previewImageName: "theme_word_neon",  description: "Hot word-game glow with electric accents."),
        CosmeticItem(id: "theme_mine_pulse", name: "Mine Pulse",  category: .boardTheme, price: 650,  previewImageName: "theme_mine_pulse", description: "Pink and gold hazard-board contrast."),
        CosmeticItem(id: "theme_crown_gold", name: "Crown Gold",  category: .boardTheme, price: 1200, previewImageName: "theme_crown_gold", description: "Icon-inspired crown gold with jewel pink."),
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
}
