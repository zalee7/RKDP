import Foundation
import Combine
import StoreKit
import FirebaseAuth

@MainActor
final class RankedStoreKitService: ObservableObject {
    static let shared = RankedStoreKitService()

    @Published private(set) var productsByID: [String: Product] = [:]
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoadingProducts = false

    private init() {}

    func loadProducts() async {
        guard productsByID.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let products = try await Product.products(for: RankedAccessProduct.storeKitProductIDs)
            productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        } catch {
            productsByID = [:]
        }
    }

    func priceText(for productID: String) -> String {
        productsByID[productID]?.displayPrice ?? RankedAccessProduct.fallbackPrice(for: productID)
    }

    func hasLoadedProduct(_ productID: String) -> Bool {
        productsByID[productID] != nil
    }

    func currentEntitlementProductIDs() async throws -> Set<String> {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard RankedAccessProduct.storeKitProductIDs.contains(transaction.productID) else { continue }
            ids.insert(transaction.productID)
        }
        purchasedProductIDs = ids
        return ids
    }

    func purchase(productID: String, userID: String) async throws -> AppUser {
        guard Auth.auth().currentUser?.uid == userID else { throw URLError(.userAuthenticationRequired) }
        let store = FirestoreService.shared
        let serverWallet = try await store.usesServerWallet(userID: userID)
        let token = serverWallet ? try await store.prepareWalletPurchase(userID: userID).appAccountToken : nil
        await loadProducts()
        guard let product = productsByID[productID] else { throw RankedStoreKitError.productUnavailable }
        guard Auth.auth().currentUser?.uid == userID else { throw URLError(.userAuthenticationRequired) }
        let result = try await product.purchase(options: token.map { [.appAccountToken($0)] } ?? [])
        switch result {
        case .success(let verification):
            let transaction = try verified(verification)
            guard transaction.productID == productID, transaction.productType == .nonConsumable,
                  transaction.revocationDate == nil else { throw RankedStoreKitError.unverified }
            let user: AppUser
            if serverWallet {
                user = try await store.claimWalletPurchase(userID: userID, signedTransaction: verification.jwsRepresentation)
            } else {
                user = try await store.syncRankedAccessEntitlements(userID: userID, productIDs: [transaction.productID])
            }
            await transaction.finish()
            _ = try await currentEntitlementProductIDs()
            return user
        case .userCancelled:
            throw RankedStoreKitError.cancelled
        case .pending:
            throw RankedStoreKitError.pending
        @unknown default:
            throw RankedStoreKitError.unknown
        }
    }

    func syncPurchases(userID: String, restoring: Bool = false) async throws -> AppUser {
        guard Auth.auth().currentUser?.uid == userID else { throw URLError(.userAuthenticationRequired) }
        if restoring { try await AppStore.sync() }
        let store = FirestoreService.shared
        guard try await store.usesServerWallet(userID: userID) else {
            return try await store.syncRankedAccessEntitlements(userID: userID, productIDs: currentEntitlementProductIDs())
        }
        let token = try await store.prepareWalletPurchase(userID: userID).appAccountToken
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  RankedAccessProduct.storeKitProductIDs.contains(transaction.productID) else { continue }
            guard transaction.appAccountToken == token else {
                if restoring { throw RankedStoreKitError.accountBindingRequired }
                continue
            }
            _ = try await deliverUpdate(result, userID: userID)
        }
        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result, transaction.appAccountToken == token else { continue }
            _ = try await deliverUpdate(result, userID: userID)
        }
        return try await store.fetchUser(id: userID)
    }

    func deliverUpdate(_ result: VerificationResult<Transaction>, userID: String) async throws -> AppUser? {
        let transaction = try verified(result)
        guard RankedAccessProduct.storeKitProductIDs.contains(transaction.productID),
              transaction.productType == .nonConsumable else { return nil }
        guard Auth.auth().currentUser?.uid == userID else { throw URLError(.userAuthenticationRequired) }
        let store = FirestoreService.shared
        guard try await store.usesServerWallet(userID: userID) else { return nil }
        let token = try await store.prepareWalletPurchase(userID: userID).appAccountToken
        guard transaction.appAccountToken == token else { return nil }
        let user = try await store.claimWalletPurchase(userID: userID, signedTransaction: result.jwsRepresentation)
        await transaction.finish()
        return user
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw RankedStoreKitError.unverified
        }
    }
}

enum RankedStoreKitError: LocalizedError {
    case productUnavailable
    case cancelled
    case pending
    case unverified
    case unknown
    case accountBindingRequired

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "This ranked pass is not available yet. Create the product in App Store Connect, then try again."
        case .cancelled:
            return "Purchase cancelled."
        case .pending:
            return "Purchase is pending approval."
        case .unverified:
            return "Could not verify that purchase. Please try restoring purchases."
        case .unknown:
            return "Could not complete that purchase. Please try again."
        case .accountBindingRequired:
            return "This older purchase needs account verification. Contact support; do not buy it again."
        }
    }
}
