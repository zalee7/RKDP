import Foundation

enum AppPreferenceKeys { static let reduceExtraAnimations = "reduceExtraAnimations" }

@main struct WalletCatalogExport {
    static func main() throws {
        let items = CosmeticCatalog.all + CosmeticCatalog.numberFonts + CosmeticCatalog.cellBorders + CosmeticCatalog.avatarPoses
        func slot(_ category: CosmeticCategory) -> String {
            switch category {
            case .title: return "equippedTitle"
            case .boardTheme: return "equippedBoardTheme"
            case .tileTheme: return "equippedTileTheme"
            case .cardTheme: return "equippedCardTheme"
            case .numberFont: return "equippedNumberFont"
            case .cellBorder: return "equippedCellBorder"
            case .avatarHead: return "equippedAvatarHead"
            case .avatarFace: return "equippedAvatarFace"
            case .avatarOutfit: return "equippedAvatarOutfit"
            case .avatarAura: return "equippedAvatarAura"
            case .avatarPose: return "equippedAvatarPose"
            }
        }
        let catalog: [String: Any] = [
            "version": 1,
            "defaultIDs": OwnedCosmetics.defaultPurchasedIDs.sorted(),
            "items": items.map { item -> [String: Any] in
                ["id": item.id, "price": item.price, "category": item.category.rawValue,
                 "slot": slot(item.category), "rarity": item.rarity.rawValue.lowercased(),
                 "available": item.isLaunchCatalogVisible && !item.category.isLegacyStoreCategory && item.category != .avatarPose]
            },
            "testDay": Int(Date().timeIntervalSince1970 / 86400),
            "testRotation": (DailyRotation.todaysAvatarShopItems(ownedIDs: []) +
                [CosmeticCategory.title, .boardTheme, .tileTheme, .cardTheme].flatMap {
                    DailyRotation.availableItems(for: $0, ownedIDs: [])
                }).map(\.id).sorted()
        ]
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: catalog, options: [.sortedKeys]))
    }
}
