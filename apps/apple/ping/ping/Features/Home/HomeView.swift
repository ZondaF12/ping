import SwiftUI
import UIKit
import UserNotifications

struct HomeView: View {
    @EnvironmentObject private var pushTokenStore: PushTokenStore
    @StateObject private var vm = HomeViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Webhook URL")
                    .font(.headline)
                Text(vm.webhookURL.isEmpty ? "Preparing…" : vm.webhookURL)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)

                Text("Bash")
                    .font(.headline)
                Text(vm.curlExample())
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 12) {
                    Button("Re-register") {
                        Task { try? await vm.register(pushToken: pushTokenStore.pushTokenHex) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.isBusy)

                    Button("Send test") {
                        Task { await vm.sendTest() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.isBusy)
                }

                if vm.isBusy { ProgressView() }
                if vm.isSyncingStartup {
                    Text("Syncing with CloudKit…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let status = vm.status {
                    Text(status)
                        .font(.subheadline)
                }
                if let log = vm.registerLog {
                    Text("Last register: \(log)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !vm.endpoints.isEmpty {
                    Text("Registered endpoints")
                        .font(.headline)
                    ForEach(vm.endpoints) { device in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.record_name)
                                .font(.caption.bold())
                            Text(device.push_token)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
        .task {
            await requestPushPermissionsAndRegisterForRemoteNotifications()
            await vm.bootstrap(pushToken: pushTokenStore.pushTokenHex)
        }
        .onChange(of: pushTokenStore.pushTokenHex) { _, newToken in
            guard let token = newToken, !token.isEmpty else { return }
            Task {
                try? await vm.register(pushToken: token)
                try? await vm.refreshEndpoints()
            }
        }
    }

    private func requestPushPermissionsAndRegisterForRemoteNotifications() async {
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

