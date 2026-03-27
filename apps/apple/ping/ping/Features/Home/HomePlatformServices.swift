import UIKit
import UserNotifications

enum HomePushPermissionService {
    static func requestAndRegisterRemoteNotifications() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } catch {
            #if DEBUG
            print("Push permission error: \(error.localizedDescription)")
            #endif
        }
    }
}

enum HomeFeedback {
    static func press() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    static func failure() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}

enum HomeClipboard {
    static func copy(text: String) {
        UIPasteboard.general.string = text
    }
}
