import SwiftUI
import UIKit
import UserNotifications

struct HomeView: View {
    @EnvironmentObject private var pushTokenStore: PushTokenStore
    @StateObject private var vm = HomeViewModel()
    @State private var copiedToastVisible = false
    @State private var hasStarted = false
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var sendTestButtonFrame: CGRect = .zero
    @State private var sendButtonState: SendButtonState = .idle
    private let emojiCelebrationEnabled = true

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.03, blue: 0.10),
                    Color(red: 0.02, green: 0.02, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 24) {
                    Spacer()
                    hero
                    curlCard
                    actionButtons
                    docsLink
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 32)

            if copiedToastVisible {
                Text("Copied")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.75), in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task {
            guard !isRunningPreview else { return }
            guard !hasStarted else { return }
            hasStarted = true
            vm.prepareForImmediateUse()
            Task {
                await requestPushPermissionsAndRegisterForRemoteNotifications()
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

    private var hero: some View {
        VStack(alignment: .leading, spacing: -10) {
            Text("Welcome")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                Text("to")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("ping")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.47, green: 0.43, blue: 1.0),
                                Color(red: 0.69, green: 0.42, blue: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
    }

    private var curlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bash")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))
                Spacer()
                Button {
                    triggerPressHaptic()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sendButtonState = .sending
                    }
                    Task {
                        let success = await vm.sendTest()
                        if success {
                            triggerSuccessFeedback()
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
                        triggerFailureFeedback()
                        await MainActor.run {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                sendButtonState = .idle
                            }
                        }
                    }
                } label: {
                    sendButtonLabel
                }
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
                .disabled(vm.isBusy)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: SendTestButtonFramePreferenceKey.self,
                            value: proxy.frame(in: .named("curlCardSpace"))
                        )
                    }
                )
            }

            Divider().overlay(.white.opacity(0.08))

            ScrollView(.horizontal, showsIndicators: true) {
                Text(styledCurlExample)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineSpacing(2)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
        .coordinateSpace(name: "curlCardSpace")
        .onPreferenceChange(SendTestButtonFramePreferenceKey.self) { frame in
            sendTestButtonFrame = frame
        }
        .overlay(alignment: .topTrailing) {
            ZStack {
                ForEach(confettiParticles) { particle in
                    ConfettiParticleView(particle: particle) {
                        removeConfettiParticle(id: particle.id)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                UIPasteboard.general.string = vm.curlExample()
                withAnimation(.easeInOut(duration: 0.18)) {
                    copiedToastVisible = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        copiedToastVisible = false
                    }
                }
            } label: {
                HStack {
                    Text("Copy")
                    Spacer()
                    Image(systemName: "doc.on.doc")
                }
                .padding(.horizontal)
            }
            .buttonStyle(PillButtonStyle(background: Color(red: 0.64, green: 0.97, blue: 0.31), foreground: .black))

            ShareLink(item: vm.curlExample()) {
                HStack {
                    Text("Share")
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                }
                .padding(.horizontal)
            }
            .buttonStyle(PillButtonStyle(background: .white, foreground: .black))
        }
    }

    private var docsLink: some View {
        Link(destination: URL(string: "https://brrr.now/how-it-works/")!) {
            Label("Read docs", systemImage: "doc.text")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
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

    private var styledCurlExample: AttributedString {
        let raw = vm.curlExample()
        var styled = AttributedString(raw)
        styled.foregroundColor = .gray

        if let urlRange = styled.range(of: vm.webhookURL), !vm.webhookURL.isEmpty {
            styled[urlRange].foregroundColor = .orange
        }
        return styled
    }

    private func triggerPressHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    private func triggerSuccessFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)

        guard emojiCelebrationEnabled else { return }
        spawnConfettiBurst()
    }

    private func triggerFailureFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    private func spawnConfettiBurst() {
        guard sendTestButtonFrame != .zero else { return }
        let origin = CGPoint(x: sendTestButtonFrame.midX, y: sendTestButtonFrame.midY)
        let emojiPool = ["🎉", "✨"]
        let count = Int.random(in: 6...10)
        var newParticles: [ConfettiParticle] = []
        newParticles.reserveCapacity(count)
        for _ in 0..<count {
            let emoji = emojiPool.randomElement() ?? "🎉"
            let launchDuration = Double.random(in: 0.48...0.68)
            let fadeDuration = Double.random(in: 0.24...0.4)
            let startX = origin.x + CGFloat.random(in: -8...8)
            let startY = origin.y - CGFloat.random(in: 4...14)
            let peakX = origin.x + CGFloat.random(in: -130...130)
            let peakY = origin.y - CGFloat.random(in: 95...150)
            let endX = peakX + CGFloat.random(in: -22...22)
            let endY = peakY + CGFloat.random(in: -8...10)
            let rotation = Double.random(in: -150...150)
            let size = CGFloat.random(in: 16...24)
            newParticles.append(
                ConfettiParticle(
                    emoji: emoji,
                    startX: startX,
                    startY: startY,
                    peakX: peakX,
                    peakY: peakY,
                    endX: endX,
                    endY: endY,
                    rotation: rotation,
                    launchDuration: launchDuration,
                    fadeDuration: fadeDuration,
                    size: size
                )
            )
        }
        confettiParticles.append(contentsOf: newParticles)
    }

    private func removeConfettiParticle(id: UUID) {
        confettiParticles.removeAll { $0.id == id }
    }

    private var isRunningPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    @ViewBuilder
    private var sendButtonLabel: some View {
        HStack(spacing: 8) {
            if sendButtonState == .sending {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            }
            Text(sendButtonState.title)
                .contentTransition(.opacity)
        }
    }
}

private enum SendButtonState {
    case idle
    case sending
    case sent

    var title: String {
        switch self {
        case .idle:
            return "Send Test"
        case .sending:
            return "Sending..."
        case .sent:
            return "Sent"
        }
    }
}

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let emoji: String
    let startX: CGFloat
    let startY: CGFloat
    let peakX: CGFloat
    let peakY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let rotation: Double
    let launchDuration: Double
    let fadeDuration: Double
    let size: CGFloat
}

private struct ConfettiParticleView: View {
    let particle: ConfettiParticle
    let onComplete: () -> Void
    @State private var phase: Int = 0

    var body: some View {
        Text(particle.emoji)
            .font(.system(size: particle.size))
            .rotationEffect(rotationForPhase)
            .opacity(opacityForPhase)
            .scaleEffect(scaleForPhase)
            .position(
                x: xForPhase,
                y: yForPhase
            )
            .onAppear {
                withAnimation(.easeOut(duration: particle.launchDuration)) {
                    phase = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + particle.launchDuration) {
                    withAnimation(.easeOut(duration: particle.fadeDuration)) {
                        phase = 2
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + particle.fadeDuration) {
                        onComplete()
                    }
                }
            }
    }

    private var xForPhase: CGFloat {
        switch phase {
        case 1:
            return particle.peakX
        case 2:
            return particle.endX
        default:
            return particle.startX
        }
    }

    private var yForPhase: CGFloat {
        switch phase {
        case 1:
            return particle.peakY
        case 2:
            return particle.endY
        default:
            return particle.startY
        }
    }

    private var opacityForPhase: Double {
        switch phase {
        case 1:
            return 1
        case 2:
            return 0
        default:
            return 1
        }
    }

    private var rotationForPhase: Angle {
        switch phase {
        case 1:
            return .degrees(particle.rotation * 0.4)
        case 2:
            return .degrees(particle.rotation)
        default:
            return .degrees(0)
        }
    }

    private var scaleForPhase: CGFloat {
        switch phase {
        case 1:
            return 1.02
        case 2:
            return 0.72
        default:
            return 1
        }
    }
}

private struct SendTestButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct PillButtonStyle: ButtonStyle {
    let background: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                background.opacity(configuration.isPressed ? 0.85 : 1.0),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(PushTokenStore())
            .previewDisplayName("Home")
    }
}

