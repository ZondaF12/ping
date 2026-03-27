import SwiftUI

struct HomeBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.03, green: 0.03, blue: 0.10),
                Color(red: 0.02, green: 0.02, blue: 0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct HomeHeroView: View {
    var body: some View {
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
}

struct HomeCurlCardView: View {
    let styledCurlExample: AttributedString
    let isBusy: Bool
    let sendButtonState: SendButtonState
    let confettiParticles: [ConfettiParticle]
    let onSendTapped: () -> Void
    let onParticleComplete: (UUID) -> Void
    let onButtonFrameChanged: (CGRect) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bash")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))
                Spacer()
                Button(action: onSendTapped) {
                    HomeSendButtonLabel(state: sendButtonState)
                }
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .glassEffect(in: Capsule())
                .disabled(isBusy)
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
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
        .coordinateSpace(.named("curlCardSpace"))
        .onPreferenceChange(SendTestButtonFramePreferenceKey.self, perform: onButtonFrameChanged)
        .overlay(alignment: .topTrailing) {
            ZStack {
                ForEach(confettiParticles) { particle in
                    ConfettiParticleView(particle: particle) {
                        onParticleComplete(particle.id)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

struct HomeActionButtonsView: View {
    let curlText: String
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onCopy) {
                HStack {
                    Text("Copy")
                    Spacer()
                    Image(systemName: "doc.on.doc")
                }
                .padding(.horizontal)
            }
            .buttonStyle(PillButtonStyle(background: Color(red: 0.64, green: 0.97, blue: 0.31), foreground: .black))

            ShareLink(item: curlText) {
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
}

struct HomeDocsLinkView: View {
    var body: some View {
        Link(destination: URL(string: "https://brrr.now/how-it-works/")!) {
            Label("Read docs", systemImage: "doc.text")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
        }
    }
}

struct HomeCopiedToastView: View {
    var body: some View {
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

struct HomeSendButtonLabel: View {
    let state: SendButtonState

    var body: some View {
        HStack(spacing: 8) {
            if state == .sending {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            }
            Text(state.title)
                .contentTransition(.opacity)
        }
    }
}

enum SendButtonState {
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

struct SendTestButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct PillButtonStyle: ButtonStyle {
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

struct ConfettiParticle: Identifiable {
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

    static func makeBurst(origin: CGPoint) -> [ConfettiParticle] {
        let emojiPool = ["🎉", "✨"]
        let count = Int.random(in: 6...10)
        var particles: [ConfettiParticle] = []
        particles.reserveCapacity(count)
        for _ in 0..<count {
            let peakX = origin.x + CGFloat.random(in: -130...130)
            let peakY = origin.y - CGFloat.random(in: 95...150)
            particles.append(
                ConfettiParticle(
                    emoji: emojiPool.randomElement() ?? "🎉",
                    startX: origin.x + CGFloat.random(in: -8...8),
                    startY: origin.y - CGFloat.random(in: 4...14),
                    peakX: peakX,
                    peakY: peakY,
                    endX: peakX + CGFloat.random(in: -22...22),
                    endY: peakY + CGFloat.random(in: -8...10),
                    rotation: Double.random(in: -150...150),
                    launchDuration: Double.random(in: 0.48...0.68),
                    fadeDuration: Double.random(in: 0.24...0.4),
                    size: CGFloat.random(in: 16...24)
                )
            )
        }
        return particles
    }
}

struct ConfettiParticleView: View {
    let particle: ConfettiParticle
    let onComplete: () -> Void
    @State private var phase: Int = 0

    var body: some View {
        Text(particle.emoji)
            .font(.system(size: particle.size))
            .rotationEffect(rotationForPhase)
            .opacity(opacityForPhase)
            .scaleEffect(scaleForPhase)
            .position(x: xForPhase, y: yForPhase)
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
        case 1: return particle.peakX
        case 2: return particle.endX
        default: return particle.startX
        }
    }

    private var yForPhase: CGFloat {
        switch phase {
        case 1: return particle.peakY
        case 2: return particle.endY
        default: return particle.startY
        }
    }

    private var opacityForPhase: Double {
        switch phase {
        case 2: return 0
        default: return 1
        }
    }

    private var rotationForPhase: Angle {
        switch phase {
        case 1: return .degrees(particle.rotation * 0.4)
        case 2: return .degrees(particle.rotation)
        default: return .degrees(0)
        }
    }

    private var scaleForPhase: CGFloat {
        switch phase {
        case 1: return 1.02
        case 2: return 0.72
        default: return 1
        }
    }
}

extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
