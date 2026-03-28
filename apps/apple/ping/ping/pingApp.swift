//
//  pingApp.swift
//  ping
//
//  Created by Ruaridh Bell on 26/03/2026.
//

import SwiftUI

@main
struct pingApp: App {
    @UIApplicationDelegateAdaptor(AppPushDelegate.self) private var appDelegate
    @StateObject private var notificationHistoryStore = NotificationHistoryStore()

    var body: some Scene {
        WindowGroup {
            PingRootView()
                .environmentObject(appDelegate.pushTokenStore)
                .environmentObject(notificationHistoryStore)
                .onAppear {
                    appDelegate.historyStore = notificationHistoryStore
                }
        }
    }
}
