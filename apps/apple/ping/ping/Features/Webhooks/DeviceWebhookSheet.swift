import SwiftUI

struct DeviceWebhookSheet: View {
    let row: DeviceEndpointRow
    @ObservedObject var homeVM: HomeViewModel
    var onRotateDevice: () async -> Void
    var onReload: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var sendButtonState: SendButtonState = .idle
    @State private var confirmRotateDevice = false

    private var showsDeviceCurl: Bool {
        !homeVM.deviceWebhookURL.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    instructionBlock

                    if showsDeviceCurl {
                        HomeCurlCardView(
                            styledCurlExample: homeVM.attributedDeviceCurlExample(),
                            isBusy: homeVM.isBusy,
                            sendButtonState: sendButtonState,
                            onSendTapped: handleDeviceSendTest
                        )

                        DeviceWebhookCopyShareRow(
                            secretText: homeVM.deviceSecret,
                            urlText: homeVM.deviceWebhookURL,
                            curlText: homeVM.deviceCurlExample(),
                            onCopy: { HomeClipboard.copy(text: $0) }
                        )
                    } else {
                        Text(
                            "Per-device webhook URLs and send test are only available on the device that owns the secret. Open \(row.deviceLabel) to copy or test."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    footerLines
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .navigationTitle(row.deviceLabel)
            .navigationBarTitleDisplayMode(.inline)
        }
        .confirmationDialog(
            "Regenerate this device’s webhook URL?",
            isPresented: $confirmRotateDevice,
            titleVisibility: .visible
        ) {
            Button("Regenerate", role: .destructive) {
                Task {
                    await onRotateDevice()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The old per-device URL stops working immediately.")
        }
    }

    private var instructionBlock: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: deviceIconName(for: row.deviceKind))
                .font(.title3)
                .foregroundStyle(.primary)
            Text("Send a notification to \(Text(row.deviceLabel).fontWeight(.semibold)) only using this webhook.")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footerLines: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let ts = row.lastSeenTimestamp, let line = Self.formattedPushReceived(ts) {
                HStack(alignment: .top, spacing: 8) {
                    Spacer()
                    Image(systemName: "bell.fill")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
            if let ts = row.lastUsedTimestamp, let line = Self.formattedWebhookUsed(ts) {
                HStack(alignment: .top, spacing: 8) {
                    Spacer()
                    Image(systemName: "link")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
        }
    }

    private func handleDeviceSendTest() {
        HomeFeedback.press()
        withAnimation(.easeInOut(duration: 0.2)) {
            sendButtonState = .sending
        }
        Task {
            let success = await homeVM.sendDeviceTest()
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
                await onReload()
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

    private func deviceIconName(for kind: String?) -> String {
        switch kind {
        case "iphone": return "iphone"
        case "ipad": return "ipad"
        case "mac": return "laptopcomputer"
        case "tv": return "tv"
        case "watch": return "applewatch"
        case "vision": return "visionpro"
        case "catalyst": return "laptopcomputer"
        default: return "desktopcomputer"
        }
    }

    private static func formattedPushReceived(_ iso: String) -> String? {
        formattedTimeline(prefix: "Push received", iso: iso)
    }

    private static func formattedWebhookUsed(_ iso: String) -> String? {
        formattedTimeline(prefix: "Webhook was used", iso: iso)
    }

    /// Shared with [WebhooksView.formattedLastUsed](WebhooksView.swift) semantics, different sentence prefix.
    private static func formattedTimeline(prefix: String, iso: String) -> String? {
        let trimmed = iso.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: trimmed)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: trimmed)
        }
        guard let date else { return "\(prefix) \(trimmed)." }
        let cal = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none
        if cal.isDateInToday(date) {
            return "\(prefix) today at \(timeFormatter.string(from: date))."
        }
        if cal.isDateInYesterday(date) {
            return "\(prefix) yesterday at \(timeFormatter.string(from: date))."
        }
        let dateTime = DateFormatter()
        dateTime.dateStyle = .medium
        dateTime.timeStyle = .short
        return "\(prefix) \(dateTime.string(from: date))."
    }
}

private struct DeviceWebhookCopyShareRow: View {
    let secretText: String
    let urlText: String
    let curlText: String
    let onCopy: (String) -> Void

    var body: some View {
        WebhookCopyShareMenusView(
            secretText: secretText,
            urlText: urlText,
            curlText: curlText,
            onCopy: onCopy
        )
    }
}
