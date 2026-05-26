import Foundation

@MainActor
final class ShopViewModel: ObservableObject {
    @Published private(set) var user: AppUser
    @Published var ownedCosmetics: OwnedCosmetics
    @Published var errorMessage: String?
    @Published var isSaving = false

    private let store = FirestoreService.shared
    private let coinStore = CoinPackStoreKitService.shared
    private let rewardedAds = RewardedAdService.shared

    init(user: AppUser) {
        self.user = user
        self.ownedCosmetics = user.cosmetics
    }

    func items(for category: CosmeticCategory) -> [CosmeticItem] {
        guard !category.isAvatarCategory else { return [] }
        let items = DailyRotation.availableItems(for: category, ownedIDs: ownedCosmetics.purchasedIDs)
        return items.sorted { lhs, rhs in
            if lhs.price != rhs.price { return lhs.price < rhs.price }
            return lhs.name < rhs.name
        }
    }

    var ownedItems: [CosmeticItem] {
        sortedForOwnership(CosmeticCatalog.all.filter { isOwned($0) && !$0.category.isAvatarCategory && !$0.category.isLegacyStoreCategory })
    }

    private func sortedForOwnership(_ items: [CosmeticItem]) -> [CosmeticItem] {
        items.sorted { lhs, rhs in
            let leftRank = ownershipSortRank(lhs)
            let rightRank = ownershipSortRank(rhs)
            if leftRank != rightRank { return leftRank < rightRank }
            if lhs.category != rhs.category { return lhs.category.rawValue < rhs.category.rawValue }
            return lhs.name < rhs.name
        }
    }

    private func ownershipSortRank(_ item: CosmeticItem) -> Int {
        if isEquipped(item) { return 0 }
        if isOwned(item) { return 1 }
        return 2
    }



    func coinPackPriceText(for pack: CoinPackProduct) -> String {
        coinStore.priceText(for: pack.id)
    }

    @discardableResult
    func purchaseCoinPack(_ pack: CoinPackProduct) async -> Bool {
        guard !isSaving else { return false }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            await coinStore.loadProducts()
            let receipt = try await coinStore.purchase(productID: pack.id)
            user = try await store.applyCoinPackPurchase(userID: user.id, productID: receipt.productID, transactionID: receipt.transactionID)
            ownedCosmetics = user.cosmetics
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func claimDailyCoins() async -> Bool {
        guard !isSaving else { return false }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            user = try await store.claimDailyCoins(userID: user.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func watchCoinAd() async -> Bool {
        guard !isSaving else { return false }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await rewardedAds.watchCoinRewardAd()
            user = try await store.grantRewardedCoins(userID: user.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    var nextRotationDate: Date { DailyRotation.nextRotationDate }

    func isOwned(_ item: CosmeticItem) -> Bool {
        ownedCosmetics.purchasedIDs.contains(item.id)
    }

    func isInTodaysRotation(_ item: CosmeticItem) -> Bool {
        guard item.category == .title, item.price > 0 else { return false }
        return DailyRotation.todaysTitles().contains { $0.id == item.id }
    }

    func isEquipped(_ item: CosmeticItem) -> Bool {
        switch item.category {
        case .title:        return ownedCosmetics.equippedTitle == item.id
        case .boardTheme:   return ownedCosmetics.equippedBoardTheme == item.id
        case .tileTheme:    return ownedCosmetics.equippedTileTheme == item.id
        case .numberFont:   return ownedCosmetics.equippedNumberFont == item.id
        case .cellBorder:   return ownedCosmetics.equippedCellBorder == item.id
        case .avatarHead:   return ownedCosmetics.equippedAvatarHead == item.id
        case .avatarFace:   return ownedCosmetics.equippedAvatarFace == item.id
        case .avatarOutfit: return ownedCosmetics.equippedAvatarOutfit == item.id
        case .avatarAura:   return ownedCosmetics.equippedAvatarAura == item.id
        case .avatarPose:   return ownedCosmetics.equippedAvatarPose == item.id
        }
    }

    func canAfford(_ item: CosmeticItem) -> Bool { user.coins >= item.price }

    @discardableResult
    func purchase(_ item: CosmeticItem) async -> Bool {
        guard !isSaving, !isOwned(item) else { return false }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        do {
            let updatedUser = try await store.purchaseCosmetic(userID: user.id, item: item)
            user = updatedUser
            ownedCosmetics = updatedUser.cosmetics
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func equip(_ item: CosmeticItem) async -> Bool {
        guard !isSaving, isOwned(item), !isEquipped(item) else { return false }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        var updatedCosmetics = ownedCosmetics
        updatedCosmetics.equip(item)
        do {
            try await store.updateCosmetics(userID: user.id, cosmetics: updatedCosmetics)
            ownedCosmetics = updatedCosmetics
            user.cosmetics = updatedCosmetics
            return true
        } catch {
            errorMessage = "Could not save that cosmetic. Please try again."
            return false
        }
    }


    @discardableResult
    func setCustomAvatarBodyHex(_ hex: String) async -> Bool {
        guard !isSaving else { return false }
        var updatedCosmetics = ownedCosmetics
        guard updatedCosmetics.setCustomAvatarBodyHex(hex) else {
            errorMessage = "Use a valid 6-digit hex color."
            return false
        }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.updateCosmetics(userID: user.id, cosmetics: updatedCosmetics)
            ownedCosmetics = updatedCosmetics
            user.cosmetics = updatedCosmetics
            return true
        } catch {
            errorMessage = "Could not save that avatar color. Please try again."
            return false
        }
    }

    var equippedTitleName: String {
        CosmeticCatalog.allTitles.first { $0.id == ownedCosmetics.equippedTitle }?.name ?? "Puzzler"
    }
}
