import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var pushTokenStore: PushTokenStore
    @StateObject private var vm = HomeViewModel()
    @State private var copiedToastVisible = false
    @State private var hasStarted = false
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var sendTestButtonFrame: CGRect = .zero
    @State private var sendButtonState: SendButtonState = .idle

    var body: some View {
        ZStack(alignment: .top) {
            HomeBackgroundView()

            VStack(alignment: .leading, spacing: 24) {
                Spacer()
                HomeHeroView()
                HomeCurlCardView(
                    styledCurlExample: styledCurlExample,
                    isBusy: vm.isBusy,
                    sendButtonState: sendButtonState,
                    confettiParticles: confettiParticles,
                    onSendTapped: handleSendTestTap,
                    onParticleComplete: removeConfettiParticle,
                    onButtonFrameChanged: { sendTestButtonFrame = $0 }
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
        .preferredColorScheme(.dark)
        .navigationTitle("")
    }

    private var styledCurlExample: AttributedString {
        let raw = vm.curlExample()
        var styled = AttributedString(raw)
        styled.foregroundColor = .gray
        if let urlRange = styled.range(of: vm.webhookURL), !vm.webhookURL.isEmpty {
            styled[urlRange].foregroundColor = .orange
        }
        return styled
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
                spawnConfettiBurst()
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

    private func spawnConfettiBurst() {
        guard sendTestButtonFrame != .zero else { return }
        confettiParticles.append(contentsOf: ConfettiParticle.makeBurst(origin: sendTestButtonFrame.center))
    }

    private func removeConfettiParticle(id: UUID) {
        confettiParticles.removeAll { $0.id == id }
    }

    private var isRunningPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(PushTokenStore())
    }
}

