import Foundation

@MainActor
final class ShopViewModel: ObservableObject {
    @Published private(set) var user: AppUser
    @Published var ownedCosmetics: OwnedCosmetics
    @Published var errorMessage: String?
    @Published var isSaving = false

    private let store = FirestoreService.shared

    init(user: AppUser) {
        self.user = user
        self.ownedCosmetics = user.cosmetics
    }

    // For titles: only show today's rotation + already-owned titles
    func items(for category: CosmeticCategory) -> [CosmeticItem] {
        if category == .title {
            let todayIDs = Set(DailyRotation.todaysTitles().map(\.id))
            return CosmeticCatalog.allTitles.filter { item in
                item.price == 0 || todayIDs.contains(item.id) || isOwned(item)
            }
        }
        return CosmeticCatalog.all.filter { $0.category == category }
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
        case .title:       return ownedCosmetics.equippedTitle == item.id
        case .boardTheme:  return ownedCosmetics.equippedBoardTheme == item.id
        case .numberFont:  return ownedCosmetics.equippedNumberFont == item.id
        case .cellBorder:  return ownedCosmetics.equippedCellBorder == item.id
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

    var equippedTitleName: String {
        CosmeticCatalog.allTitles.first { $0.id == ownedCosmetics.equippedTitle }?.name ?? "Puzzler"
    }
}
