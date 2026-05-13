import SwiftUI

// MARK: - Shop item types

enum CosmeticCategory: String, Codable, CaseIterable {
    case title       = "Titles"
    case boardTheme  = "Board Theme"
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
        CosmeticItem(id: "theme_classic",   name: "Classic",      category: .boardTheme,  price: 0,    previewImageName: "theme_classic",   description: "The default clean look."),
        CosmeticItem(id: "theme_dark",      name: "Dark Mode",    category: .boardTheme,  price: 200,  previewImageName: "theme_dark",      description: "Sleek dark grid on OLED-friendly black."),
        CosmeticItem(id: "theme_ocean",     name: "Ocean",        category: .boardTheme,  price: 350,  previewImageName: "theme_ocean",     description: "Cool blues with wave-ripple highlights."),
        CosmeticItem(id: "theme_forest",    name: "Forest",       category: .boardTheme,  price: 350,  previewImageName: "theme_forest",    description: "Earthy greens and wood-brown cells."),
        CosmeticItem(id: "theme_neon",      name: "Neon",         category: .boardTheme,  price: 600,  previewImageName: "theme_neon",      description: "Vibrant neon glow on dark backgrounds."),
        CosmeticItem(id: "theme_gold",      name: "Gold Edition", category: .boardTheme,  price: 1500, previewImageName: "theme_gold",      description: "Premium gold-leaf grid for Master-tier players."),
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
