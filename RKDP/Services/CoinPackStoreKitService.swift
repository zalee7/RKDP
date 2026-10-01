import Foundation
import Combine
import StoreKit
import FirebaseAuth

@MainActor
final class CoinPackStoreKitService: ObservableObject {
    static let shared = CoinPackStoreKitService()

    @Published private(set) var productsByID: [String: Product] = [:]
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var pendingDeliveryError: String?
    private var transactionListener: Task<Void, Never>?
    private var observingUserID: String?

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

    func purchase(productID: String, userID: String) async throws -> CoinPackPurchaseReceipt {
        guard Auth.auth().currentUser?.uid == userID else { throw URLError(.userAuthenticationRequired) }
        let serverWallet = try await FirestoreService.shared.usesServerWallet(userID: userID)
        let token: UUID
        if serverWallet {
            let preparation = try await FirestoreService.shared.prepareWalletPurchase(userID: userID)
            guard preparation.refundDebt == 0 else { throw CoinPackStoreKitError.refundAdjustmentPending }
            token = preparation.appAccountToken
        } else {
            token = accountToken(for: userID)
        }
        await loadProducts()
        #if DEBUG
        if !serverWallet, productsByID[productID] == nil, let pack = CoinPackProduct.pack(for: productID) {
            return CoinPackPurchaseReceipt(productID: pack.id, transactionID: "debug-\(pack.id)-\(UUID().uuidString)", userID: userID)
        }
        #endif
        guard let product = productsByID[productID] else { throw CoinPackStoreKitError.productUnavailable }
        guard Auth.auth().currentUser?.uid == userID else { throw URLError(.userAuthenticationRequired) }
        let result = try await product.purchase(options: [.appAccountToken(token)])
        switch result {
        case .success(let verification):
            let transaction = try verified(verification)
            guard transaction.revocationDate == nil, transaction.productType == .consumable,
                  transaction.productID == productID else { throw CoinPackStoreKitError.unverified }
            UserDefaults.standard.set(userID, forKey: ownerKey(transaction.id))
            return CoinPackPurchaseReceipt(productID: transaction.productID, transactionID: String(transaction.id), userID: userID,
                                           transaction: transaction, signedTransaction: verification.jwsRepresentation)
        case .userCancelled:
            throw CoinPackStoreKitError.cancelled
        case .pending:
            throw CoinPackStoreKitError.pending
        @unknown default:
            throw CoinPackStoreKitError.unknown
        }
    }

    func deliver(_ receipt: CoinPackPurchaseReceipt) async throws -> AppUser {
        guard Auth.auth().currentUser?.uid == receipt.userID else { throw URLError(.userAuthenticationRequired) }
        let user: AppUser
        do {
            if try await FirestoreService.shared.usesServerWallet(userID: receipt.userID) {
                guard let signed = receipt.signedTransaction else { throw CoinPackStoreKitError.unverified }
                user = try await FirestoreService.shared.claimWalletPurchase(userID: receipt.userID, signedTransaction: signed)
            } else {
                user = try await FirestoreService.shared.applyCoinPackPurchase(userID: receipt.userID,
                    productID: receipt.productID, transactionID: receipt.transactionID)
            }
        } catch {
            if receipt.transaction != nil {
                pendingDeliveryError = "A coin purchase is awaiting delivery. Retry when you are connected."
            }
            throw error
        }
        // Durable grant first. On failure StoreKit keeps the transaction unfinished.
        if let transaction = receipt.transaction {
            await transaction.finish()
            UserDefaults.standard.removeObject(forKey: ownerKey(transaction.id))
        }
        pendingDeliveryError = nil
        return user
    }

    func observePurchases(userID: String, onDelivery: @escaping (AppUser) -> Void) {
        guard observingUserID != userID else { return }
        stopObservingPurchases()
        observingUserID = userID
        transactionListener = Task { [weak self] in
            for await update in Transaction.updates {
                guard !Task.isCancelled, let self else { return }
                do {
                    if let user = try await RankedStoreKitService.shared.deliverUpdate(update, userID: userID) {
                        onDelivery(user)
                        continue
                    }
                } catch {
                    self.pendingDeliveryError = "A ranked purchase is awaiting delivery. Use Restore Purchases to retry."
                }
                if let user = await self.recover(update, userID: userID) { onDelivery(user) }
            }
        }
    }

    func recoverPurchases(userID: String) async -> AppUser? {
        var latest: AppUser?
        for await transaction in Transaction.unfinished {
            guard !Task.isCancelled, Auth.auth().currentUser?.uid == userID else { break }
            if let delivered = await recover(transaction, userID: userID) { latest = delivered }
        }
        return latest
    }

    func stopObservingPurchases() {
        transactionListener?.cancel()
        transactionListener = nil
        observingUserID = nil
        pendingDeliveryError = nil
    }

    private func recover(_ result: VerificationResult<Transaction>, userID: String) async -> AppUser? {
        do {
            let transaction = try verified(result)
            guard CoinPackProduct.pack(for: transaction.productID) != nil,
                  transaction.productType == .consumable,
                  Auth.auth().currentUser?.uid == userID else { return nil }
            if try await FirestoreService.shared.usesServerWallet(userID: userID) {
                let token = try await FirestoreService.shared.prepareWalletPurchase(userID: userID).appAccountToken
                guard transaction.appAccountToken == token else { return nil }
                return try await deliver(CoinPackPurchaseReceipt(productID: transaction.productID,
                    transactionID: String(transaction.id), userID: userID, transaction: transaction,
                    signedTransaction: result.jwsRepresentation))
            }
            guard transaction.revocationDate == nil else { return nil }
            let recordedOwner = UserDefaults.standard.string(forKey: ownerKey(transaction.id))
            let token = UserDefaults.standard.string(forKey: "coinAccountToken_\(userID)").flatMap(UUID.init(uuidString:))
            // Never assign an unbound legacy purchase to whichever account logs in.
            guard recordedOwner == userID || (token != nil && transaction.appAccountToken == token) else { return nil }
            return try await deliver(CoinPackPurchaseReceipt(productID: transaction.productID,
                transactionID: String(transaction.id), userID: userID, transaction: transaction))
        } catch {
            pendingDeliveryError = "A coin purchase is awaiting delivery. It will be retried when you reconnect."
            return nil
        }
    }

    private func accountToken(for userID: String) -> UUID {
        let key = "coinAccountToken_\(userID)"
        if let value = UserDefaults.standard.string(forKey: key), let token = UUID(uuidString: value) { return token }
        let token = UUID()
        UserDefaults.standard.set(token.uuidString, forKey: key)
        return token
    }

    private func ownerKey(_ transactionID: UInt64) -> String { "coinPurchaseOwner_\(transactionID)" }

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
    var userID: String
    var transaction: Transaction? = nil
    var signedTransaction: String? = nil
}

enum CoinPackStoreKitError: LocalizedError {
    case productUnavailable
    case cancelled
    case pending
    case unverified
    case unknown
    case refundAdjustmentPending

    var errorDescription: String? {
        switch self {
        case .productUnavailable: return "This coin pack is not available yet. Create it in App Store Connect, then try again."
        case .cancelled: return "Purchase cancelled."
        case .pending: return "Purchase is pending approval."
        case .unverified: return "Could not verify that purchase. Please try again."
        case .unknown: return "Could not complete that purchase. Please try again."
        case .refundAdjustmentPending:
            return "A previous refund has a remaining coin adjustment. Earned coins will clear it. Coin purchases are paused until then; contact support if this looks incorrect."
        }
    }
}
