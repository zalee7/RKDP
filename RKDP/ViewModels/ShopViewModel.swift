import Foundation

@MainActor
final class ShopViewModel: ObservableObject {
    @Published var ownedCosmetics: OwnedCosmetics
    @Published var errorMessage: String?

    private var user: AppUser
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
        case .title:       return ownedCosmetics.equippedTitle      == item.id
        case .boardTheme:  return ownedCosmetics.equippedBoardTheme == item.id
        case .numberFont:  return ownedCosmetics.equippedNumberFont == item.id
        case .cellBorder:  return ownedCosmetics.equippedCellBorder == item.id
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
        case .title:       ownedCosmetics.equippedTitle      = item.id
        case .boardTheme:  ownedCosmetics.equippedBoardTheme = item.id
        case .numberFont:  ownedCosmetics.equippedNumberFont = item.id
        case .cellBorder:  ownedCosmetics.equippedCellBorder = item.id
        }
        persistCosmetics()
    }

    private func persistCosmetics() {
        let snapshot = ownedCosmetics
        Task { try? await store.updateCosmetics(userID: user.id, cosmetics: snapshot) }
    }

    var equippedTitleName: String {
        CosmeticCatalog.allTitles.first { $0.id == ownedCosmetics.equippedTitle }?.name ?? "Puzzler"
    }
}
