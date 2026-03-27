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
    let onSendTapped: () -> Void

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

