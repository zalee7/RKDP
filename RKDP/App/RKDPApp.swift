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
}

final class NotificationTokenService {
    static let shared = NotificationTokenService()

    private let db = Firestore.firestore()

    private init() {}

    func syncCurrentToken() async {
        do {
            let token = try await Messaging.messaging().token()
            await saveFCMToken(token)
        } catch {
            print("Failed to fetch FCM token: \(error.localizedDescription)")
        }
    }

    func saveFCMToken(_ token: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        do {
            try await db.collection("users").document(uid).setData([
                "fcmTokens": FieldValue.arrayUnion([token]),
                "fcmTokenUpdatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            print("Failed to save FCM token: \(error.localizedDescription)")
        }
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
