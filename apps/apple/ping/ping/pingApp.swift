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

    var body: some Scene {
        WindowGroup {
            PingRootView()
                .environmentObject(appDelegate.pushTokenStore)
        }
    }
}
