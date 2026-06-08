import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        requestNotificationPermission(application)

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
        Messaging.messaging().apnsToken = deviceToken
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task {
            await NotificationTokenService.shared.saveFCMToken(fcmToken)
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

    private init() {}

    func syncCurrentToken() async {
        do {
            let token = try await currentFCMToken()
            await saveFCMToken(token)
        } catch {
            print("Failed to fetch FCM token: \(error.localizedDescription)")
        }
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
    @StateObject private var auth = AuthViewModel()

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
        }
    }
}
