import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications
import UIKit

#if PP_RANKED_SANDBOX && !PP_SOCIAL_SANDBOX
#error("Ranked test builds require the isolated social sandbox configuration.")
#endif
#if (PP_PURCHASE_SANDBOX || PP_SOCIAL_SANDBOX) && !DEBUG
#error("Sandbox builds must never be built for release.")
#endif
#if PP_PURCHASE_SANDBOX && PP_SOCIAL_SANDBOX
#error("Select only one sandbox entry point.")
#endif

enum FirebaseBootstrap {
    static func configureIfNeeded() {
        if FirebaseApp.app() == nil {
            #if PP_PURCHASE_SANDBOX || PP_SOCIAL_SANDBOX
            guard let config = Bundle.main.object(forInfoDictionaryKey: "PPTestFirebase") as? [String: String],
                  config["PROJECT_ID"] == "puzzlepartytest",
                  config["BUNDLE_ID"] == "com.rkdp.app",
                  let appID = config["GOOGLE_APP_ID"], let senderID = config["GCM_SENDER_ID"],
                  let apiKey = config["API_KEY"] else {
                fatalError("Missing or incorrect purchase sandbox configuration. Production fallback is forbidden.")
            }
            let options = FirebaseOptions(googleAppID: appID, gcmSenderID: senderID)
            options.apiKey = apiKey
            options.projectID = "puzzlepartytest"
            options.bundleID = "com.rkdp.app"
            FirebaseApp.configure(options: options)
            #else
            FirebaseApp.configure()
            #endif
        }
        #if PP_PURCHASE_SANDBOX || PP_SOCIAL_SANDBOX
        precondition(FirebaseApp.app()?.options.projectID == "puzzlepartytest")
        #endif
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseBootstrap.configureIfNeeded()

        #if !PP_PURCHASE_SANDBOX && !PP_SOCIAL_SANDBOX
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        requestNotificationPermission(application)
        #endif

        return true
    }

    private func requestNotificationPermission(_ application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                print("Notification permission error: \(error.localizedDescription)")
            }

            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task {
            await NotificationTokenService.shared.handleAPNSToken(deviceToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task {
            await NotificationTokenService.shared.handleRegistrationToken(fcmToken)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let type = userInfo["type"] as? String,
           type == "party_invite",
           let code = userInfo["roomCode"] as? String {
            PartyJoinLink.storePending(code)
            NotificationCenter.default.post(name: .partyJoinRequested, object: nil)
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let partyJoinRequested = Notification.Name("PartyJoinRequested")
}

enum PartyJoinLink {
    static let pendingCodeKey = "pendingPartyJoinCode"

    static func code(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "puzzleparty" else { return nil }
        var pieces: [String] = []
        if let host = url.host, !host.isEmpty { pieces.append(host) }
        pieces.append(contentsOf: url.pathComponents.filter { $0 != "/" })

        if pieces.first?.lowercased() == "join", pieces.count > 1 {
            return normalizedCode(pieces[1])
        }
        return pieces.last.flatMap(normalizedCode)
    }

    static func storePending(_ code: String) {
        guard let normalized = normalizedCode(code) else { return }
        UserDefaults.standard.set(normalized, forKey: pendingCodeKey)
    }

    static func consumePending() -> String? {
        guard let code = UserDefaults.standard.string(forKey: pendingCodeKey) else { return nil }
        UserDefaults.standard.removeObject(forKey: pendingCodeKey)
        return normalizedCode(code)
    }

    private static func normalizedCode(_ raw: String) -> String? {
        let code = raw
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
        return code.isEmpty ? nil : code
    }
}

final class NotificationTokenService {
    static let shared = NotificationTokenService()

    private let db = Firestore.firestore()
    private var needsSyncAfterAPNSToken = false

    private init() {}

    func syncCurrentToken() async {
        #if PP_PURCHASE_SANDBOX || PP_SOCIAL_SANDBOX
        return
        #else
        guard hasAPNSToken else {
            needsSyncAfterAPNSToken = true
            print("Deferring FCM token sync until APNS token is set.")
            return
        }

        do {
            let token = try await currentFCMToken()
            needsSyncAfterAPNSToken = false
            await saveFCMToken(token)
        } catch {
            print("Failed to fetch FCM token: \(error.localizedDescription)")
        }
        #endif
    }

    func handleAPNSToken(_ deviceToken: Data) async {
        Messaging.messaging().apnsToken = deviceToken
        if needsSyncAfterAPNSToken || Auth.auth().currentUser != nil {
            await syncCurrentToken()
        }
    }

    func handleRegistrationToken(_ fcmToken: String?) async {
        guard let fcmToken else { return }
        guard hasAPNSToken else {
            needsSyncAfterAPNSToken = true
            print("Deferring FCM registration token save until APNS token is set.")
            return
        }
        await saveFCMToken(fcmToken)
    }

    private func currentFCMToken() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            Messaging.messaging().token { token, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let token {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: NotificationTokenError.missingToken)
                }
            }
        }
    }

    func saveFCMToken(_ token: String) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("Skipping FCM token save because no user is signed in yet.")
            return
        }

        do {
            try await db.collection("users").document(uid).setData([
                "fcmTokens": FieldValue.arrayUnion([token]),
                "fcmTokenUpdatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            print("Saved FCM token for user \(uid): \(token.prefix(12))...")
        } catch {
            print("Failed to save FCM token: \(error.localizedDescription)")
        }
    }

    private var hasAPNSToken: Bool {
        Messaging.messaging().apnsToken != nil
    }
}

private enum NotificationTokenError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        "Firebase did not return an FCM token."
    }
}

@main
struct GridDuelApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #if !PP_PURCHASE_SANDBOX
    @StateObject private var auth: AuthViewModel
    #endif

    init() {
        FirebaseBootstrap.configureIfNeeded()
        #if !PP_PURCHASE_SANDBOX
        _auth = StateObject(wrappedValue: AuthViewModel())
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if PP_PURCHASE_SANDBOX
            PurchaseSandboxView()
            #else
            RootView()
                .environmentObject(auth)
            #endif
        }
    }
}

#if PP_PURCHASE_SANDBOX
import StoreKit
import Security

// Deliberately bypasses AuthViewModel and gameplay: their legacy writers must
// not run against the purchase-only test wallet. Uses the real purchase services.
private struct PurchaseSandboxView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var userID: String?
    @State private var balance: Int?
    @State private var access = "None"
    @State private var ready = false
    @State private var keychainReady = false
    @State private var busy = false
    @State private var status = "Not signed in"
    @State private var deliveryPaused = false
    @State private var unfinishedCoinPurchases = 0
    @State private var accountToken: UUID?
    @StateObject private var coins = CoinPackStoreKitService.shared
    @StateObject private var ranked = RankedStoreKitService.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Test Environment") {
                    LabeledContent("Firebase", value: "puzzlepartytest")
                    LabeledContent("Apple", value: "Sandbox only")
                    Text(status).foregroundStyle(.secondary)
                    if let error = coins.pendingDeliveryError {
                        Text(error).foregroundStyle(.red)
                    }
                }
                if let uid = userID {
                    Section("Test Account") {
                        Text(uid).font(.footnote.monospaced()).textSelection(.enabled)
                        LabeledContent("Server balance", value: balance.map { String($0) } ?? "Not provisioned")
                        LabeledContent("Ranked access", value: access)
                        LabeledContent("Unfinished coin purchases", value: String(unfinishedCoinPurchases))
                        Button("Refresh", systemImage: "arrow.clockwise") { run { try await refresh(uid) } }
                        Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") {
                            coins.stopObservingPurchases()
                            do {
                                try Auth.auth().signOut()
                                userID = nil
                                balance = nil
                                ready = false
                                access = "None"
                                accountToken = nil
                                unfinishedCoinPurchases = 0
                                status = "Not signed in"
                            } catch { status = error.localizedDescription }
                        }
                    }
                    Section("Coin Packs") {
                        ForEach(CoinPackProduct.all) { pack in
                            Button {
                                run {
                                    let receipt = try await coins.purchase(productID: pack.id, userID: uid)
                                    _ = try await coins.deliver(receipt)
                                    try await refresh(uid)
                                    status = "Purchase delivered and balance refreshed"
                                }
                            } label: {
                                LabeledContent("\(pack.coins) coins", value: coins.priceText(for: pack.id))
                            }
                            .disabled(!ready || coins.productsByID[pack.id] == nil)
                        }
                    }
                    Section("Ranked Pass") {
                        Button("All Modes: \(ranked.priceText(for: "com.gridduel.ranked.all"))") {
                            run {
                                _ = try await ranked.purchase(productID: "com.gridduel.ranked.all", userID: uid)
                                try await refresh(uid)
                            }
                        }
                        .disabled(!ready || !ranked.hasLoadedProduct("com.gridduel.ranked.all"))
                        Button("Restore / Retry Purchases", systemImage: "arrow.clockwise") {
                            run {
                                _ = await coins.recoverPurchases(userID: uid)
                                _ = try await ranked.syncPurchases(userID: uid, restoring: true)
                                try await refresh(uid)
                            }
                        }
                        .disabled(!ready)
                    }
                    Section("Sandbox Refund Test") {
                        Button("Request Ranked Refund", systemImage: "arrow.uturn.backward") {
                            run { try await requestRankedRefund(uid) }
                        }
                        .disabled(!ready)
                    }
                    Section("Sandbox Recovery Test") {
                        Button("Buy 1,000: Pause Before Delivery", systemImage: "pause.circle") {
                            run { try await purchaseAndPause(uid) }
                        }
                        .disabled(!ready || coins.productsByID["com.gridduel.coins.small"] == nil)
                    }
                } else {
                    Section("Test Login") {
                        TextField("Email", text: $email)
                            .textContentType(.username).keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        SecureField("Password", text: $password).textContentType(.password)
                        Button("Sign In") { authenticate(create: false) }
                        Button("Create Test Account") { authenticate(create: true) }
                    }
                    .disabled(!keychainReady)
                }
            }
            .disabled(busy || deliveryPaused)
            .navigationTitle("Purchase Test")
            .overlay { if busy { ProgressView().padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)) } }
            .task {
                do {
                    try checkTestKeychain()
                    keychainReady = true
                } catch {
                    status = error.localizedDescription
                    return
                }
                if let uid = Auth.auth().currentUser?.uid {
                    userID = uid
                    run { try await resumePurchaseSession(uid) }
                }
            }
        }
    }

    private func checkTestKeychain() throws {
        // Only probes a new, disposable item belonging to this app. Never reads
        // Firebase credentials or deletes existing keychain entries.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.rkdp.purchase-test.preflight",
            kSecAttrAccount as String: UUID().uuidString
        ]
        let value = Data("purchase-test-check".utf8)
        var add = query
        add[kSecValueData as String] = value
        let added = SecItemAdd(add as CFDictionary, nil)
        guard added == errSecSuccess else { throw keychainError(added) }
        defer { SecItemDelete(query as CFDictionary) }
        var read = query
        read[kSecReturnData as String] = true
        var result: CFTypeRef?
        let copied = SecItemCopyMatching(read as CFDictionary, &result)
        guard copied == errSecSuccess, result as? Data == value else { throw keychainError(copied) }
        print("Purchase sandbox keychain preflight passed.")
    }

    private func keychainError(_ code: OSStatus) -> NSError {
        NSError(domain: "PurchaseTestKeychain", code: Int(code), userInfo: [NSLocalizedDescriptionKey:
            "Test-build keychain check failed (\(code)). Rebuild with simulator signing enabled before signing in."])
    }

    private func authenticate(create: Bool) {
        run {
            let login = email.trimmingCharacters(in: .whitespacesAndNewlines)
            let result = try await (create
                ? Auth.auth().createUser(withEmail: login, password: password)
                : Auth.auth().signIn(withEmail: login, password: password))
            password = ""
            userID = result.user.uid
            try await resumePurchaseSession(result.user.uid)
        }
    }

    @MainActor
    private func purchaseAndPause(_ uid: String) async throws {
        guard FirebaseApp.app()?.options.projectID == "puzzlepartytest",
              Auth.auth().currentUser?.uid == uid else {
            throw URLError(.userAuthenticationRequired)
        }
        let preparation = try await FirestoreService.shared.prepareWalletPurchase(userID: uid)
        guard preparation.environment == "Sandbox" else { throw CoinPackStoreKitError.unverified }
        accountToken = preparation.appAccountToken
        guard await countUnfinishedCoins(uid) == 0 else {
            status = "An earlier coin purchase is unfinished. Use Restore / Retry first."
            return
        }
        // Stop the client update listener before payment so it cannot race the
        // intentional delivery pause. Server notifications remain enabled.
        coins.stopObservingPurchases()
        do {
            let receipt = try await coins.purchase(productID: "com.gridduel.coins.small", userID: uid)
            guard let transaction = receipt.transaction,
                  transaction.environment == .sandbox,
                  transaction.appAccountToken == preparation.appAccountToken,
                  Auth.auth().currentUser?.uid == uid else { throw CoinPackStoreKitError.unverified }
            deliveryPaused = true
            unfinishedCoinPurchases = await countUnfinishedCoins(uid)
            status = "Apple payment verified. Client delivery paused; transaction not finished."
            // Intentionally no deliver() or finish(). StoreKit retains the
            // transaction across termination; the next launch uses recovery.
        } catch {
            observePurchaseUpdates(uid)
            throw error
        }
    }

    @MainActor
    private func countUnfinishedCoins(_ uid: String) async -> Int {
        guard let accountToken, Auth.auth().currentUser?.uid == uid else { return 0 }
        var count = 0
        for await result in StoreKit.Transaction.unfinished {
            guard case .verified(let transaction) = result,
                  transaction.environment == .sandbox,
                  transaction.appAccountToken == accountToken,
                  transaction.productType == .consumable,
                  CoinPackProduct.pack(for: transaction.productID) != nil else { continue }
            count += 1
        }
        return count
    }

    @MainActor
    private func resumePurchaseSession(_ uid: String) async throws {
        coins.stopObservingPurchases()
        try await refresh(uid, observeUpdates: false)
        guard ready else { return }
        let pendingBefore = await countUnfinishedCoins(uid)
        _ = await coins.recoverPurchases(userID: uid)
        try await refresh(uid)
        if pendingBefore > 0 {
            status = unfinishedCoinPurchases == 0
                ? "Unfinished coin purchase recovered and finished. Server balance refreshed."
                : "Coin purchase still awaiting delivery. Use Restore / Retry when connected."
        }
    }

    @MainActor
    private func observePurchaseUpdates(_ uid: String) {
        coins.observePurchases(userID: uid) { _ in
            run { try await refresh(uid) }
        }
    }

    @MainActor
    private func requestRankedRefund(_ uid: String) async throws {
        guard FirebaseApp.app()?.options.projectID == "puzzlepartytest",
              Auth.auth().currentUser?.uid == uid else {
            throw URLError(.userAuthenticationRequired)
        }
        let preparation = try await FirestoreService.shared.prepareWalletPurchase(userID: uid)
        guard preparation.environment == "Sandbox" else { throw RankedStoreKitError.unverified }
        guard let result = await StoreKit.Transaction.latest(for: RankedAccessProduct.allAccessProductID),
              case .verified(let transaction) = result,
              transaction.environment == .sandbox,
              transaction.productID == RankedAccessProduct.allAccessProductID,
              transaction.productType == .nonConsumable,
              transaction.appAccountToken == preparation.appAccountToken,
              Auth.auth().currentUser?.uid == uid else {
            status = "No verified sandbox ranked purchase for this account."
            return
        }
        guard transaction.revocationDate == nil else {
            try await refresh(uid)
            status = "Apple already revoked this purchase. Refresh to check server access."
            return
        }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            status = "Open this screen in the foreground to request a sandbox refund."
            return
        }
        switch try await transaction.beginRefundRequest(in: scene) {
        case .success:
            status = "Refund request submitted to Apple. Approval is separate; refresh shortly to check access."
        case .userCancelled:
            status = "Refund request cancelled."
        @unknown default:
            status = "Refund request status unknown. Refresh to check access."
        }
    }

    private func refresh(_ uid: String, observeUpdates: Bool = true) async throws {
        ready = false
        let snapshot = try await Firestore.firestore().collection("coinWallets").document(uid).getDocument(source: .server)
        guard snapshot.exists else {
            status = "Signed in. Waiting for test wallet setup."
            return
        }
        balance = (snapshot.data()?["balance"] as? NSNumber)?.intValue
        let preparation = try await FirestoreService.shared.prepareWalletPurchase(userID: uid)
        guard preparation.environment == "Sandbox" else { throw CoinPackStoreKitError.unverified }
        accountToken = preparation.appAccountToken
        let user = try await FirestoreService.shared.fetchUser(id: uid)
        access = user.rankedAccess.allModesUnlocked ? "All modes" : "\(user.rankedAccess.unlockedModeIDs.count) modes"
        await coins.loadProducts()
        await ranked.loadProducts()
        unfinishedCoinPurchases = await countUnfinishedCoins(uid)
        if observeUpdates && !deliveryPaused { observePurchaseUpdates(uid) }
        ready = true
        status = coins.productsByID.isEmpty ? "Wallet ready. Apple products unavailable on this device." : "Ready for sandbox purchase"
    }

    private func run(_ action: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do { try await action() }
            catch { status = error.localizedDescription }
        }
    }
}
#endif
