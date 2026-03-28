import SwiftUI

struct PingRootView: View {
    @EnvironmentObject private var notificationHistoryStore: NotificationHistoryStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            HomeView()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await notificationHistoryStore.syncDeliveredNotifications()
                }
            }
        }
    }
}

