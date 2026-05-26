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
        self == .free ? AppTheme.textPrimary : .white
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
    var equippedNumberFont: String
    var equippedCellBorder: String
    var equippedAvatarHead: String
    var equippedAvatarFace: String
    var equippedAvatarOutfit: String
    var equippedAvatarAura: String
    var equippedAvatarPose: String
    var customAvatarBodyHex: String

    static let defaultPurchasedIDs: Set<String> = [
        "title_puzzler", "theme_classic", "tile_classic", "font_default", "border_default",
        "avatar_head_none", "avatar_face_smile", "avatar_outfit_basic", "avatar_aura_none", "avatar_pose_neutral", "avatar_pose_jump"
    ]

    static let `default` = OwnedCosmetics(
        purchasedIDs: defaultPurchasedIDs,
        equippedTitle: "title_puzzler",
        equippedBoardTheme: "theme_classic",
        equippedTileTheme: "tile_classic",
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
        case equippedAvatarHead, equippedAvatarFace, equippedAvatarOutfit, equippedAvatarAura, equippedAvatarPose, customAvatarBodyHex
    }

    init(
        purchasedIDs: Set<String>,
        equippedTitle: String,
        equippedBoardTheme: String,
        equippedTileTheme: String = "tile_classic",
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
    static let all: [CosmeticItem] = allTitles + boardThemes + tileThemes + avatarHeads + avatarFaces + avatarOutfits + avatarAuras

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

    static let tileThemes: [CosmeticItem] = [
        CosmeticItem(id: "tile_classic", name: "Classic Tiles", category: .tileTheme, price: 0, previewImageName: "tile_classic", description: "Clean default puzzle tiles."),
        CosmeticItem(id: "tile_neon_pop", name: "Neon Pop", category: .tileTheme, price: 550, previewImageName: "tile_neon_pop", description: "Bright pink and purple arcade tiles."),
        CosmeticItem(id: "tile_mint_glass", name: "Mint Glass", category: .tileTheme, price: 700, previewImageName: "tile_mint_glass", description: "Cool mint tiles with a glassy glow."),
        CosmeticItem(id: "tile_lava_core", name: "Lava Core", category: .tileTheme, price: 1_250, previewImageName: "tile_lava_core", description: "Hot lava tiles for high-pressure games."),
        CosmeticItem(id: "tile_crown_gold", name: "Crown Gold", category: .tileTheme, price: 1_900, previewImageName: "tile_crown_gold", description: "Gold tiles inspired by the Puzzle Party crown."),
        CosmeticItem(id: "tile_diamond", name: "Diamond Shine", category: .tileTheme, price: 3_000, previewImageName: "tile_diamond", description: "Legendary bright tiles with a diamond sheen."),
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
        CosmeticItem(id: "avatar_head_crown",      name: "Crown",          category: .avatarHead, price: 1_200, previewImageName: "", description: "A tiny champion crown."),
        CosmeticItem(id: "avatar_head_headphones", name: "Headphones",     category: .avatarHead, price: 700,   previewImageName: "", description: "Locked-in puzzle focus."),
        CosmeticItem(id: "avatar_head_wizard",     name: "Wizard Hat",     category: .avatarHead, price: 1_500, previewImageName: "", description: "For strange grid magic."),
        CosmeticItem(id: "avatar_head_lightning",  name: "Lightning Hair", category: .avatarHead, price: 2_500, previewImageName: "", description: "Fast solve energy."),
        CosmeticItem(id: "avatar_head_halo",       name: "Halo",           category: .avatarHead, price: 4_000, previewImageName: "", description: "Legendary clean-play glow."),
        CosmeticItem(id: "avatar_head_puzzle_crown", name: "Puzzle Crown", category: .avatarHead, price: 1_800, previewImageName: "", description: "A crown shaped for the puzzle arena."),
        CosmeticItem(id: "avatar_head_neon_visor", name: "Neon Visor", category: .avatarHead, price: 1_300, previewImageName: "", description: "A bright visor for fast reads."),
        CosmeticItem(id: "avatar_head_star_clip", name: "Star Clip", category: .avatarHead, price: 650, previewImageName: "", description: "A tiny star for a sharp little mascot."),
        CosmeticItem(id: "avatar_head_lava_helmet", name: "Lava Helmet", category: .avatarHead, price: 2_600, previewImageName: "", description: "Heat-proof gear for rescue runs."),
        CosmeticItem(id: "avatar_head_pixel_cap", name: "Pixel Cap", category: .avatarHead, price: 850, previewImageName: "", description: "Retro arcade headwear."),
        CosmeticItem(id: "avatar_head_mini_crown", name: "Mini Crown", category: .avatarHead, price: 500, previewImageName: "", description: "Small crown, big confidence.")
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
        CosmeticItem(id: "avatar_face_heart", name: "Heart Eyes", category: .avatarFace, price: 1_900, previewImageName: "", description: "Cute heart-eyed party energy.")
    ]

    static let avatarOutfits: [CosmeticItem] = [
        CosmeticItem(id: "avatar_outfit_basic", name: "Custom Solid", category: .avatarOutfit, price: 0,     previewImageName: "", description: "Pick any solid puzzle-piece color."),
        CosmeticItem(id: "avatar_outfit_hoodie", name: "Teal Piece",  category: .avatarOutfit, price: 900,   previewImageName: "", description: "Fresh teal puzzle body."),
        CosmeticItem(id: "avatar_outfit_cape",   name: "Diamond Pink", category: .avatarOutfit, price: 1_400, previewImageName: "", description: "A glossy jewel-pink premium body."),
        CosmeticItem(id: "avatar_outfit_armor",  name: "Royal Blue",  category: .avatarOutfit, price: 2_400, previewImageName: "", description: "Royal-blue ranked body with shield detail."),
        CosmeticItem(id: "avatar_outfit_neon",   name: "Neon Piece", category: .avatarOutfit, price: 3_200, previewImageName: "", description: "Purple arcade puzzle body with neon trim."),
        CosmeticItem(id: "avatar_outfit_royal",  name: "Crown Gold", category: .avatarOutfit, price: 4_500, previewImageName: "", description: "Legendary crown-gold puzzle body."),
        CosmeticItem(id: "avatar_outfit_lava", name: "Lava Core", category: .avatarOutfit, price: 1_800, previewImageName: "", description: "Molten orange with arena heat."),
        CosmeticItem(id: "avatar_outfit_frost", name: "Frost Piece", category: .avatarOutfit, price: 1_200, previewImageName: "", description: "Cool blue ice-gloss body."),
        CosmeticItem(id: "avatar_outfit_galaxy", name: "Galaxy Piece", category: .avatarOutfit, price: 3_800, previewImageName: "", description: "A tiny night sky in puzzle form."),
        CosmeticItem(id: "avatar_outfit_mint", name: "Mint Glow", category: .avatarOutfit, price: 900, previewImageName: "", description: "Soft mint with bright white trim."),
        CosmeticItem(id: "avatar_outfit_candy", name: "Candy Piece", category: .avatarOutfit, price: 1_600, previewImageName: "", description: "Pink and blue candy arcade shine."),
        CosmeticItem(id: "avatar_outfit_obsidian", name: "Obsidian Piece", category: .avatarOutfit, price: 4_200, previewImageName: "", description: "Dark glass for legendary style.")
    ]

    static let avatarAuras: [CosmeticItem] = [
        CosmeticItem(id: "avatar_aura_none",  name: "None",        category: .avatarAura, price: 0,     previewImageName: "", description: "No aura equipped."),
        CosmeticItem(id: "avatar_aura_teal",  name: "Teal Glow",   category: .avatarAura, price: 900,   previewImageName: "", description: "Soft Color Link energy."),
        CosmeticItem(id: "avatar_aura_pink",  name: "Pink Spark",  category: .avatarAura, price: 1_200, previewImageName: "", description: "Hot-pink victory sparks."),
        CosmeticItem(id: "avatar_aura_crown", name: "Crown Shine", category: .avatarAura, price: 2_500, previewImageName: "", description: "Gold rank radiance."),
        CosmeticItem(id: "avatar_aura_storm", name: "Storm Ring",  category: .avatarAura, price: 4_000, previewImageName: "", description: "Legendary arena energy."),
        CosmeticItem(id: "avatar_aura_lava", name: "Lava Bubble", category: .avatarAura, price: 1_600, previewImageName: "", description: "Warm rescue-run bubbles."),
        CosmeticItem(id: "avatar_aura_star", name: "Star Burst", category: .avatarAura, price: 2_200, previewImageName: "", description: "A burst of tiny arcade stars."),
        CosmeticItem(id: "avatar_aura_pixel", name: "Pixel Ring", category: .avatarAura, price: 1_100, previewImageName: "", description: "Retro square energy."),
        CosmeticItem(id: "avatar_aura_mint", name: "Mint Mist", category: .avatarAura, price: 900, previewImageName: "", description: "Soft mint glow around the piece."),
        CosmeticItem(id: "avatar_aura_royal", name: "Royal Pulse", category: .avatarAura, price: 3_200, previewImageName: "", description: "Gold and pink rank energy.")
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
