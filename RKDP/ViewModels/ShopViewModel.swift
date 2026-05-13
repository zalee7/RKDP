import Foundation

@MainActor
final class ShopViewModel: ObservableObject {
    @Published var ownedCosmetics: OwnedCosmetics
    @Published var errorMessage: String?

    private var user: AppUser
    private let store = FirestoreService.shared

    init(user: AppUser) {
        self.user = user
        // Load owned cosmetics from user's Firestore doc if available
        self.ownedCosmetics = .default
    }

    var catalog: [CosmeticItem] { CosmeticCatalog.all }

    func items(for category: CosmeticCategory) -> [CosmeticItem] {
        CosmeticCatalog.all.filter { $0.category == category }
    }

    func isOwned(_ item: CosmeticItem) -> Bool {
        ownedCosmetics.purchasedIDs.contains(item.id)
    }

    func isEquipped(_ item: CosmeticItem) -> Bool {
        switch item.category {
        case .boardTheme:  return ownedCosmetics.equippedBoardTheme  == item.id
        case .avatar:      return ownedCosmetics.equippedAvatar      == item.id
        case .numberFont:  return ownedCosmetics.equippedNumberFont  == item.id
        case .cellBorder:  return ownedCosmetics.equippedCellBorder  == item.id
        }
    }

    func canAfford(_ item: CosmeticItem) -> Bool { user.coins >= item.price }

    func purchase(_ item: CosmeticItem) async {
        guard canAfford(item), !isOwned(item) else { return }
        do {
            try await store.updateCoins(userID: user.id, delta: -item.price)
            user.coins -= item.price
            ownedCosmetics.purchasedIDs.insert(item.id)
            equip(item)
        } catch { errorMessage = error.localizedDescription }
    }

    func equip(_ item: CosmeticItem) {
        guard isOwned(item) else { return }
        switch item.category {
        case .boardTheme:  ownedCosmetics.equippedBoardTheme  = item.id
        case .avatar:      ownedCosmetics.equippedAvatar      = item.id
        case .numberFont:  ownedCosmetics.equippedNumberFont  = item.id
        case .cellBorder:  ownedCosmetics.equippedCellBorder  = item.id
        }
    }
}
