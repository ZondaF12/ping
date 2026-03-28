import UIKit
import UserNotifications

final class AppPushDelegate: NSObject, UIApplicationDelegate {
    let pushTokenStore = PushTokenStore()
    /// Set from `pingApp` after the store is created (device-local history only; never uploaded).
    weak var historyStore: NotificationHistoryStore?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        DispatchQueue.main.async {
            self.pushTokenStore.pushTokenHex = token
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("APNs registration failed: \(error.localizedDescription)")
        #endif
    }
}

extension AppPushDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        await MainActor.run {
            historyStore?.recordIfNew(notification)
        }
        return [.banner, .badge, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            historyStore?.recordIfNew(response.notification)
        }
        guard
            let rawURL = response.notification.request.content.userInfo["url"] as? String,
            let destination = URL(string: rawURL),
            let scheme = destination.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            #if DEBUG
            if response.notification.request.content.userInfo["url"] != nil {
                print("Ignoring invalid notification url payload")
            }
            #endif
            return
        }

        await MainActor.run {
            UIApplication.shared.open(destination)
        }
    }
}
