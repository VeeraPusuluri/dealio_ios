import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications

// MARK: - App delegate (Firebase + push/FCM setup)

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()

        // Firebase Cloud Messaging
        Messaging.messaging().delegate = self

        // Local/remote notification presentation
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error { print("[Push] authorization error: \(error)") }
            guard granted else { print("[Push] notifications not authorized"); return }
            DispatchQueue.main.async { application.registerForRemoteNotifications() }
        }

        return true
    }

    // APNs device token → hand to Firebase so it can mint an FCM token
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Push] APNs registration failed: \(error)")
    }

    // MARK: MessagingDelegate — FCM registration token (changes over time)
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        print("[FCM] registration token: \(fcmToken)")
        // Forward this token to the backend so it can target this device for pushes.
        PushRegistrar.shared.updateToken(fcmToken)
        NotificationCenter.default.post(name: .fcmTokenReceived, object: nil, userInfo: ["token": fcmToken])
    }

    // MARK: UNUserNotificationCenterDelegate — foreground + tap handling
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("[Push] tapped notification: \(userInfo)")
        completionHandler()
    }
}

extension Notification.Name {
    /// Posted when a fresh FCM registration token arrives — observe to sync it to the backend.
    static let fcmTokenReceived = Notification.Name("dealio.fcmTokenReceived")
}

// MARK: - App entry point

@main
struct DealioBuilderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var auth = AuthStore()
    @StateObject private var serverMonitor = ServerStatusMonitor()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if serverMonitor.isDown {
                    ServerDownView(monitor: serverMonitor)
                        .transition(.opacity)
                } else {
                    RootView()
                        .environmentObject(auth)
                        .tint(.brandTeal)
                        .transition(.opacity)
                }

                if showSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: serverMonitor.isDown)
        }
    }
}
