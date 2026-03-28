import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var pushTokenStore: PushTokenStore
    @EnvironmentObject private var notificationHistoryStore: NotificationHistoryStore
    @StateObject private var vm = HomeViewModel()
    @State private var copiedToastVisible = false
    @State private var hasStarted = false
    @State private var sendButtonState: SendButtonState = .idle
    @State private var showSettings = false
    @State private var showRecentNotifications = false

    var body: some View {
        ZStack(alignment: .top) {
            HomeBackgroundView()

            VStack(alignment: .leading, spacing: 24) {
                Spacer()
                HomeHeroView()
                HomeCurlCardView(
                    styledCurlExample: vm.attributedCurlExample(),
                    isBusy: vm.isBusy,
                    sendButtonState: sendButtonState,
                    onSendTapped: handleSendTestTap
                )
                HomeActionButtonsView(
                    curlText: vm.curlExample(),
                    onCopy: copyCurlSnippet
                )
                HomeDocsLinkView()
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 32)

            if copiedToastVisible {
                HomeCopiedToastView()
            }
        }
        .task {
            guard !isRunningPreview else { return }
            guard !hasStarted else { return }
            hasStarted = true
            vm.prepareForImmediateUse()
            Task {
                await HomePushPermissionService.requestAndRegisterRemoteNotifications()
            }
            Task {
                await vm.syncInBackground(pushToken: pushTokenStore.pushTokenHex)
            }
        }
        .onChange(of: pushTokenStore.pushTokenHex) { _, newToken in
            guard let token = newToken, !token.isEmpty else { return }
            Task {
                try? await vm.register(pushToken: token)
            }
        }
        .sheet(isPresented: $showRecentNotifications) {
            NavigationStack {
                RecentNotificationsView()
            }
            .environmentObject(notificationHistoryStore)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
            .environmentObject(vm)
        }
        .onChange(of: showSettings) { _, isPresented in
            if !isPresented {
                vm.prepareForImmediateUse()
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showRecentNotifications = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .accessibilityLabel("Recent notifications")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityLabel("Settings")
            }
        }
    }

    private func handleSendTestTap() {
        HomeFeedback.press()
        withAnimation(.easeInOut(duration: 0.2)) {
            sendButtonState = .sending
        }
        Task {
            let success = await vm.sendTest()
            if success {
                HomeFeedback.success()
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sendButtonState = .sent
                    }
                }
                try? await Task.sleep(nanoseconds: 900_000_000)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        sendButtonState = .idle
                    }
                }
                return
            }
            HomeFeedback.failure()
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    sendButtonState = .idle
                }
            }
        }
    }

    private func copyCurlSnippet() {
        HomeClipboard.copy(text: vm.curlExample())
        withAnimation(.easeInOut(duration: 0.18)) {
            copiedToastVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                copiedToastVisible = false
            }
        }
    }

    private var isRunningPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(PushTokenStore())
            .environmentObject(NotificationHistoryStore())
    }
}

