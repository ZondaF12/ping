import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var pushTokenStore: PushTokenStore
    @StateObject private var vm = HomeViewModel()
    @State private var copiedToastVisible = false
    @State private var hasStarted = false
    @State private var sendButtonState: SendButtonState = .idle
    @State private var confirmRotateUserWebhook = false
    @State private var showRotateUserError = false
    @State private var rotateUserErrorMessage = ""

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
                    onSendTapped: handleSendTestTap
                )
                HomeActionButtonsView(
                    curlText: vm.curlExample(),
                    onCopy: copyCurlSnippet
                )
                Button {
                    confirmRotateUserWebhook = true
                } label: {
                    Label("Regenerate webhook URL", systemImage: "arrow.clockwise")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(.orange.opacity(0.95))
                .disabled(vm.isBusy || vm.webhookURL.isEmpty)
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
        .confirmationDialog(
            "Regenerate your user webhook URL?",
            isPresented: $confirmRotateUserWebhook,
            titleVisibility: .visible
        ) {
            Button("Regenerate", role: .destructive) {
                Task {
                    do {
                        try await vm.rotateUserWebhook(pushToken: pushTokenStore.pushTokenHex)
                    } catch {
                        rotateUserErrorMessage = error.localizedDescription
                        showRotateUserError = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The old URL stops working immediately. Per-device URLs are unchanged unless you rotate them on the Devices screen.")
        }
        .alert("Couldn’t rotate webhook", isPresented: $showRotateUserError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(rotateUserErrorMessage)
        }
        .preferredColorScheme(.dark)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    DeviceEndpointsView()
                } label: {
                    Image(systemName: "ipad.and.iphone")
                }
                .accessibilityLabel("Device endpoints")
            }
        }
    }

    private var styledCurlExample: AttributedString {
        let raw = vm.curlExample()
        var styled = AttributedString(raw)
        styled.foregroundColor = .gray
        if let urlRange = styled.range(of: vm.webhookURL), !vm.webhookURL.isEmpty {
            styled[urlRange].foregroundColor = .purple
        }
        if let dataFlagRange = raw.range(of: "-d '") {
            let payloadStart = dataFlagRange.upperBound
            if let payloadEnd = raw[payloadStart...].firstIndex(of: "'") {
                let openingQuote = raw.index(before: payloadStart)
                let payloadWithQuotes = String(raw[openingQuote...payloadEnd])
                if let payloadRange = styled.range(of: payloadWithQuotes) {
                    styled[payloadRange].foregroundColor = .green
                }
            }
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
    }
}

