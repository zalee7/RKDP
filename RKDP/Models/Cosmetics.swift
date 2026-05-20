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
    case title        = "Titles"
    case boardTheme   = "Game Theme"
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
}

struct CosmeticItem: Identifiable, Codable {
    var id: String
    var name: String
    var category: CosmeticCategory
    var price: Int
    var previewImageName: String
    var description: String
}

struct AvatarStyle: Codable, Equatable {
    var head: String
    var face: String
    var outfit: String
    var aura: String
    var pose: String

    static let `default` = AvatarStyle(
        head: "avatar_head_none",
        face: "avatar_face_smile",
        outfit: "avatar_outfit_basic",
        aura: "avatar_aura_none",
        pose: "avatar_pose_neutral"
    )
}

struct OwnedCosmetics: Codable {
    var purchasedIDs: Set<String>
    var equippedTitle: String
    var equippedBoardTheme: String
    var equippedNumberFont: String
    var equippedCellBorder: String
    var equippedAvatarHead: String
    var equippedAvatarFace: String
    var equippedAvatarOutfit: String
    var equippedAvatarAura: String
    var equippedAvatarPose: String

    static let defaultPurchasedIDs: Set<String> = [
        "title_puzzler", "theme_classic", "font_default", "border_default",
        "avatar_head_none", "avatar_face_smile", "avatar_outfit_basic", "avatar_aura_none", "avatar_pose_neutral"
    ]

    static let `default` = OwnedCosmetics(
        purchasedIDs: defaultPurchasedIDs,
        equippedTitle: "title_puzzler",
        equippedBoardTheme: "theme_classic",
        equippedNumberFont: "font_default",
        equippedCellBorder: "border_default",
        equippedAvatarHead: AvatarStyle.default.head,
        equippedAvatarFace: AvatarStyle.default.face,
        equippedAvatarOutfit: AvatarStyle.default.outfit,
        equippedAvatarAura: AvatarStyle.default.aura,
        equippedAvatarPose: AvatarStyle.default.pose
    )

    var avatarStyle: AvatarStyle {
        AvatarStyle(
            head: equippedAvatarHead,
            face: equippedAvatarFace,
            outfit: equippedAvatarOutfit,
            aura: equippedAvatarAura,
            pose: equippedAvatarPose
        )
    }

    enum CodingKeys: String, CodingKey {
        case purchasedIDs, equippedTitle, equippedBoardTheme, equippedNumberFont, equippedCellBorder
        case equippedAvatarHead, equippedAvatarFace, equippedAvatarOutfit, equippedAvatarAura, equippedAvatarPose
    }

    init(
        purchasedIDs: Set<String>,
        equippedTitle: String,
        equippedBoardTheme: String,
        equippedNumberFont: String,
        equippedCellBorder: String,
        equippedAvatarHead: String,
        equippedAvatarFace: String,
        equippedAvatarOutfit: String,
        equippedAvatarAura: String,
        equippedAvatarPose: String
    ) {
        self.purchasedIDs = purchasedIDs.union(Self.defaultPurchasedIDs)
        self.equippedTitle = equippedTitle
        self.equippedBoardTheme = equippedBoardTheme
        self.equippedNumberFont = equippedNumberFont
        self.equippedCellBorder = equippedCellBorder
        self.equippedAvatarHead = equippedAvatarHead
        self.equippedAvatarFace = equippedAvatarFace
        self.equippedAvatarOutfit = equippedAvatarOutfit
        self.equippedAvatarAura = equippedAvatarAura
        self.equippedAvatarPose = equippedAvatarPose
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.default
        purchasedIDs = (try c.decodeIfPresent(Set<String>.self, forKey: .purchasedIDs) ?? defaults.purchasedIDs).union(Self.defaultPurchasedIDs)
        equippedTitle = try c.decodeIfPresent(String.self, forKey: .equippedTitle) ?? defaults.equippedTitle
        equippedBoardTheme = try c.decodeIfPresent(String.self, forKey: .equippedBoardTheme) ?? defaults.equippedBoardTheme
        equippedNumberFont = try c.decodeIfPresent(String.self, forKey: .equippedNumberFont) ?? defaults.equippedNumberFont
        equippedCellBorder = try c.decodeIfPresent(String.self, forKey: .equippedCellBorder) ?? defaults.equippedCellBorder
        equippedAvatarHead = try c.decodeIfPresent(String.self, forKey: .equippedAvatarHead) ?? defaults.equippedAvatarHead
        equippedAvatarFace = try c.decodeIfPresent(String.self, forKey: .equippedAvatarFace) ?? defaults.equippedAvatarFace
        equippedAvatarOutfit = try c.decodeIfPresent(String.self, forKey: .equippedAvatarOutfit) ?? defaults.equippedAvatarOutfit
        equippedAvatarAura = try c.decodeIfPresent(String.self, forKey: .equippedAvatarAura) ?? defaults.equippedAvatarAura
        equippedAvatarPose = try c.decodeIfPresent(String.self, forKey: .equippedAvatarPose) ?? defaults.equippedAvatarPose
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(purchasedIDs, forKey: .purchasedIDs)
        try c.encode(equippedTitle, forKey: .equippedTitle)
        try c.encode(equippedBoardTheme, forKey: .equippedBoardTheme)
        try c.encode(equippedNumberFont, forKey: .equippedNumberFont)
        try c.encode(equippedCellBorder, forKey: .equippedCellBorder)
        try c.encode(equippedAvatarHead, forKey: .equippedAvatarHead)
        try c.encode(equippedAvatarFace, forKey: .equippedAvatarFace)
        try c.encode(equippedAvatarOutfit, forKey: .equippedAvatarOutfit)
        try c.encode(equippedAvatarAura, forKey: .equippedAvatarAura)
        try c.encode(equippedAvatarPose, forKey: .equippedAvatarPose)
    }

    mutating func equip(_ item: CosmeticItem) {
        purchasedIDs.insert(item.id)
        switch item.category {
        case .title:        equippedTitle = item.id
        case .boardTheme:   equippedBoardTheme = item.id
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
    static let all: [CosmeticItem] = allTitles + boardThemes + numberFonts + cellBorders + avatarHeads + avatarFaces + avatarOutfits + avatarAuras + avatarPoses

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
    ]

    static let boardThemes: [CosmeticItem] = [
        CosmeticItem(id: "theme_classic",    name: "Classic",     category: .boardTheme, price: 0,    previewImageName: "theme_classic",    description: "The default clean look."),
        CosmeticItem(id: "theme_dark",       name: "Dark Mode",   category: .boardTheme, price: 200,  previewImageName: "theme_dark",       description: "Sleek dark panels for focused puzzle runs."),
        CosmeticItem(id: "theme_ocean",      name: "Ocean",       category: .boardTheme, price: 350,  previewImageName: "theme_ocean",      description: "Cool blues for calm grid solving."),
        CosmeticItem(id: "theme_forest",     name: "Forest",      category: .boardTheme, price: 350,  previewImageName: "theme_forest",     description: "Earthy greens for quiet board play."),
        CosmeticItem(id: "theme_neon",       name: "Neon",        category: .boardTheme, price: 600,  previewImageName: "theme_neon",       description: "Arcade glow for fast ranked matches."),
        CosmeticItem(id: "theme_gold",       name: "Gold Edition", category: .boardTheme, price: 1_800, previewImageName: "theme_gold",       description: "Premium gold-leaf styling for top ranks."),
        CosmeticItem(id: "theme_color_link", name: "Color Link",  category: .boardTheme, price: 700,  previewImageName: "theme_color_link", description: "Teal, pink, and blue path energy."),
        CosmeticItem(id: "theme_grid_duel",  name: "Grid Duel",   category: .boardTheme, price: 700,  previewImageName: "theme_grid_duel",  description: "Gold and blue target-board shine."),
        CosmeticItem(id: "theme_word_neon",  name: "Word Neon",   category: .boardTheme, price: 650,  previewImageName: "theme_word_neon",  description: "Hot word-game glow with electric accents."),
        CosmeticItem(id: "theme_mine_pulse", name: "Mine Pulse",  category: .boardTheme, price: 650,  previewImageName: "theme_mine_pulse", description: "Pink and gold hazard-board contrast."),
        CosmeticItem(id: "theme_crown_gold", name: "Crown Gold",  category: .boardTheme, price: 2_500, previewImageName: "theme_crown_gold", description: "Icon-inspired crown gold with jewel pink."),
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
        CosmeticItem(id: "avatar_head_none",       name: "Clean",          category: .avatarHead, price: 0,     previewImageName: "", description: "Classic stick dueler head."),
        CosmeticItem(id: "avatar_head_crown",      name: "Crown",          category: .avatarHead, price: 1_200, previewImageName: "", description: "A tiny champion crown."),
        CosmeticItem(id: "avatar_head_headphones", name: "Headphones",     category: .avatarHead, price: 700,   previewImageName: "", description: "Locked-in puzzle focus."),
        CosmeticItem(id: "avatar_head_wizard",     name: "Wizard Hat",     category: .avatarHead, price: 1_500, previewImageName: "", description: "For strange grid magic."),
        CosmeticItem(id: "avatar_head_lightning",  name: "Lightning Hair", category: .avatarHead, price: 2_500, previewImageName: "", description: "Fast solve energy."),
        CosmeticItem(id: "avatar_head_halo",       name: "Halo",           category: .avatarHead, price: 4_000, previewImageName: "", description: "Legendary clean-play glow.")
    ]

    static let avatarFaces: [CosmeticItem] = [
        CosmeticItem(id: "avatar_face_smile",   name: "Smile",    category: .avatarFace, price: 0,     previewImageName: "", description: "Friendly default expression."),
        CosmeticItem(id: "avatar_face_focused", name: "Focused",  category: .avatarFace, price: 500,   previewImageName: "", description: "Locked on the puzzle."),
        CosmeticItem(id: "avatar_face_wink",    name: "Wink",     category: .avatarFace, price: 700,   previewImageName: "", description: "A little postgame confidence."),
        CosmeticItem(id: "avatar_face_shades",  name: "Shades",   category: .avatarFace, price: 1_200, previewImageName: "", description: "Cool under ranked pressure."),
        CosmeticItem(id: "avatar_face_gem",     name: "Gem Eyes", category: .avatarFace, price: 2_000, previewImageName: "", description: "Icon-pink jewel intensity.")
    ]

    static let avatarOutfits: [CosmeticItem] = [
        CosmeticItem(id: "avatar_outfit_basic", name: "Basic",      category: .avatarOutfit, price: 0,     previewImageName: "", description: "Simple white-outline dueler."),
        CosmeticItem(id: "avatar_outfit_hoodie", name: "Hoodie",    category: .avatarOutfit, price: 900,   previewImageName: "", description: "Casual ranked comfort."),
        CosmeticItem(id: "avatar_outfit_cape",   name: "Cape",      category: .avatarOutfit, price: 1_400, previewImageName: "", description: "Victory-ready silhouette."),
        CosmeticItem(id: "avatar_outfit_armor",  name: "Armor",     category: .avatarOutfit, price: 2_400, previewImageName: "", description: "Built for tough grids."),
        CosmeticItem(id: "avatar_outfit_neon",   name: "Neon Suit", category: .avatarOutfit, price: 3_200, previewImageName: "", description: "Arcade-bright ranked drip."),
        CosmeticItem(id: "avatar_outfit_royal",  name: "Royal Robe", category: .avatarOutfit, price: 4_500, previewImageName: "", description: "A legendary crown-era look.")
    ]

    static let avatarAuras: [CosmeticItem] = [
        CosmeticItem(id: "avatar_aura_none",  name: "None",        category: .avatarAura, price: 0,     previewImageName: "", description: "No aura equipped."),
        CosmeticItem(id: "avatar_aura_teal",  name: "Teal Glow",   category: .avatarAura, price: 900,   previewImageName: "", description: "Soft Color Link energy."),
        CosmeticItem(id: "avatar_aura_pink",  name: "Pink Spark",  category: .avatarAura, price: 1_200, previewImageName: "", description: "Hot-pink victory sparks."),
        CosmeticItem(id: "avatar_aura_crown", name: "Crown Shine", category: .avatarAura, price: 2_500, previewImageName: "", description: "Gold rank radiance."),
        CosmeticItem(id: "avatar_aura_storm", name: "Storm Ring",  category: .avatarAura, price: 4_000, previewImageName: "", description: "Legendary arena energy.")
    ]

    static let avatarPoses: [CosmeticItem] = [
        CosmeticItem(id: "avatar_pose_neutral",  name: "Neutral",  category: .avatarPose, price: 0,     previewImageName: "", description: "Ready for the next puzzle."),
        CosmeticItem(id: "avatar_pose_victory",  name: "Victory",  category: .avatarPose, price: 700,   previewImageName: "", description: "One arm up after a win."),
        CosmeticItem(id: "avatar_pose_thinking", name: "Thinking", category: .avatarPose, price: 700,   previewImageName: "", description: "A puzzler's pause."),
        CosmeticItem(id: "avatar_pose_ready",    name: "Ready",    category: .avatarPose, price: 1_100, previewImageName: "", description: "Squared up for ranked."),
        CosmeticItem(id: "avatar_pose_flex",     name: "Flex",     category: .avatarPose, price: 1_500, previewImageName: "", description: "For confident board clears.")
    ]

}
