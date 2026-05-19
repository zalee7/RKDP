import Foundation
import Combine
import StoreKit

@MainActor
final class CoinPackStoreKitService: ObservableObject {
    static let shared = CoinPackStoreKitService()

    @Published private(set) var productsByID: [String: Product] = [:]
    @Published private(set) var isLoadingProducts = false

    private init() {}

    func loadProducts() async {
        guard productsByID.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let products = try await Product.products(for: CoinPackProduct.productIDs)
            productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        } catch {
            productsByID = [:]
        }
    }

    func priceText(for productID: String) -> String {
        productsByID[productID]?.displayPrice ?? CoinPackProduct.pack(for: productID)?.fallbackPrice ?? "$0.99"
    }

    func purchase(productID: String) async throws -> CoinPackPurchaseReceipt {
        await loadProducts()
        #if DEBUG
        if productsByID[productID] == nil, let pack = CoinPackProduct.pack(for: productID) {
            return CoinPackPurchaseReceipt(productID: pack.id, transactionID: "debug-\(pack.id)-\(UUID().uuidString)")
        }
        #endif
        guard let product = productsByID[productID] else { throw CoinPackStoreKitError.productUnavailable }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verified(verification)
            await transaction.finish()
            return CoinPackPurchaseReceipt(productID: transaction.productID, transactionID: String(transaction.id))
        case .userCancelled:
            throw CoinPackStoreKitError.cancelled
        case .pending:
            throw CoinPackStoreKitError.pending
        @unknown default:
            throw CoinPackStoreKitError.unknown
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw CoinPackStoreKitError.unverified
        }
    }
}

struct CoinPackPurchaseReceipt {
    var productID: String
    var transactionID: String
}

enum CoinPackStoreKitError: LocalizedError {
    case productUnavailable
    case cancelled
    case pending
    case unverified
    case unknown

    var errorDescription: String? {
        switch self {
        case .productUnavailable: return "This coin pack is not available yet. Create it in App Store Connect, then try again."
        case .cancelled: return "Purchase cancelled."
        case .pending: return "Purchase is pending approval."
        case .unverified: return "Could not verify that purchase. Please try again."
        case .unknown: return "Could not complete that purchase. Please try again."
        }
    }
}
