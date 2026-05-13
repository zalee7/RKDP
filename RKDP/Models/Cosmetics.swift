import SwiftUI

// MARK: - Shop item types

enum CosmeticCategory: String, Codable, CaseIterable {
    case boardTheme   = "Board Theme"
    case avatar       = "Avatar"
    case numberFont   = "Number Style"
    case cellBorder   = "Cell Border"
}

struct CosmeticItem: Identifiable, Codable {
    var id: String
    var name: String
    var category: CosmeticCategory
    var price: Int              // coin cost
    var previewImageName: String
    var description: String
}

struct OwnedCosmetics: Codable {
    var purchasedIDs: Set<String>
    var equippedBoardTheme: String
    var equippedAvatar: String
    var equippedNumberFont: String
    var equippedCellBorder: String

    static let `default` = OwnedCosmetics(
        purchasedIDs: ["theme_classic", "avatar_default", "font_default", "border_default"],
        equippedBoardTheme: "theme_classic",
        equippedAvatar: "avatar_default",
        equippedNumberFont: "font_default",
        equippedCellBorder: "border_default"
    )
}

// MARK: - Catalog

struct CosmeticCatalog {
    static let all: [CosmeticItem] = boardThemes + avatars + numberFonts + cellBorders

    static let boardThemes: [CosmeticItem] = [
        CosmeticItem(id: "theme_classic",   name: "Classic",      category: .boardTheme,  price: 0,    previewImageName: "theme_classic",   description: "The default clean look."),
        CosmeticItem(id: "theme_dark",      name: "Dark Mode",    category: .boardTheme,  price: 200,  previewImageName: "theme_dark",      description: "Sleek dark grid on OLED-friendly black."),
        CosmeticItem(id: "theme_ocean",     name: "Ocean",        category: .boardTheme,  price: 350,  previewImageName: "theme_ocean",     description: "Cool blues with wave-ripple highlights."),
        CosmeticItem(id: "theme_forest",    name: "Forest",       category: .boardTheme,  price: 350,  previewImageName: "theme_forest",    description: "Earthy greens and wood-brown cells."),
        CosmeticItem(id: "theme_neon",      name: "Neon",         category: .boardTheme,  price: 600,  previewImageName: "theme_neon",      description: "Vibrant neon glow on dark backgrounds."),
        CosmeticItem(id: "theme_gold",      name: "Gold Edition", category: .boardTheme,  price: 1500, previewImageName: "theme_gold",      description: "Premium gold-leaf grid for Master-tier players."),
    ]

    static let avatars: [CosmeticItem] = [
        CosmeticItem(id: "avatar_default",  name: "Puzzler",      category: .avatar, price: 0,    previewImageName: "avatar_default",  description: "Your default puzzle champion."),
        CosmeticItem(id: "avatar_robot",    name: "Robo",         category: .avatar, price: 300,  previewImageName: "avatar_robot",    description: "A sleek robot solver."),
        CosmeticItem(id: "avatar_wizard",   name: "Wizard",       category: .avatar, price: 400,  previewImageName: "avatar_wizard",   description: "Masters the arcane arts of logic."),
        CosmeticItem(id: "avatar_ninja",    name: "Ninja",        category: .avatar, price: 400,  previewImageName: "avatar_ninja",    description: "Swift and silent."),
        CosmeticItem(id: "avatar_panda",    name: "Panda",        category: .avatar, price: 500,  previewImageName: "avatar_panda",    description: "Deceptively skilled."),
        CosmeticItem(id: "avatar_master",   name: "Grand Master", category: .avatar, price: 2000, previewImageName: "avatar_master",   description: "Reserved for the elite."),
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
