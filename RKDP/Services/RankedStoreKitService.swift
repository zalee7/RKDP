import Foundation
import Combine
import StoreKit

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

    func purchase(productID: String) async throws -> Set<String> {
        await loadProducts()
        guard let product = productsByID[productID] else { throw RankedStoreKitError.productUnavailable }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verified(verification)
            await transaction.finish()
            return try await currentEntitlementProductIDs()
        case .userCancelled:
            throw RankedStoreKitError.cancelled
        case .pending:
            throw RankedStoreKitError.pending
        @unknown default:
            throw RankedStoreKitError.unknown
        }
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
        }
    }
}
