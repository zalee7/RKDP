import Foundation
import Combine

@MainActor
final class RankedAccessViewModel: ObservableObject {
    @Published private(set) var user: AppUser
    @Published var errorMessage: String?
    @Published var isWorking = false

    private let store = FirestoreService.shared
    private let storeKit = RankedStoreKitService.shared
    private let rewardedAds = RewardedAdService.shared

    init(user: AppUser) {
        self.user = user
        Task { await storeKit.loadProducts() }
    }

    func priceText(for productID: String) -> String {
        storeKit.priceText(for: productID)
    }

    func productConfigured(_ productID: String) -> Bool {
        storeKit.hasLoadedProduct(productID)
    }

    func purchase(productID: String) async -> Bool {
        guard !isWorking else { return false }
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            let productIDs = try await storeKit.purchase(productID: productID)
            user = try await store.syncRankedAccessEntitlements(userID: user.id, productIDs: productIDs)
            return true
        } catch RankedStoreKitError.cancelled {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restorePurchases() async -> Bool {
        guard !isWorking else { return false }
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            let productIDs = try await storeKit.currentEntitlementProductIDs()
            user = try await store.syncRankedAccessEntitlements(userID: user.id, productIDs: productIDs)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func watchAdForRankedTicket(mode: GameMode) async -> Bool {
        guard !isWorking else { return false }
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await rewardedAds.watchRankedEntryAd()
            user = try await store.grantRewardedRankedTicket(userID: user.id, mode: mode)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
