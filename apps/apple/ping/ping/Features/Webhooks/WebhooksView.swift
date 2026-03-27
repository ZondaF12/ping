import SwiftUI

struct WebhooksView: View {
    @EnvironmentObject private var homeVM: HomeViewModel
    @EnvironmentObject private var pushTokenStore: PushTokenStore
    @StateObject private var vm = WebhooksViewModel()
    @State private var sendButtonState: SendButtonState = .idle
    @State private var confirmRotateUser = false
    @State private var showRotateUserError = false
    @State private var rotateUserErrorMessage = ""
    @State private var selectedDevice: DeviceEndpointRow?

    var body: some View {
        List {
            privacyBanner
            userSection
            devicesSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Webhooks")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if vm.isLoading || vm.isRotating {
                ProgressView()
            }
        }
        .confirmationDialog(
            "Regenerate your user webhook URL?",
            isPresented: $confirmRotateUser,
            titleVisibility: .visible
        ) {
            Button("Regenerate", role: .destructive) {
                Task {
                    do {
                        try await homeVM.rotateUserWebhook(pushToken: pushTokenStore.pushTokenHex)
                        await vm.load()
                    } catch {
                        rotateUserErrorMessage = error.localizedDescription
                        showRotateUserError = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The old URL stops working immediately. Per-device URLs are unchanged unless you rotate them on this screen.")
        }
        .alert("Couldn’t rotate webhook", isPresented: $showRotateUserError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(rotateUserErrorMessage)
        }
        .task {
            await vm.load()
        }
        .refreshable {
            await vm.load()
        }
        .sheet(item: $selectedDevice) { row in
            DeviceWebhookSheet(
                row: row,
                homeVM: homeVM,
                onRotateDevice: {
                    await vm.rotateLocalDeviceWebhook(pushToken: pushTokenStore.pushTokenHex)
                    homeVM.prepareForImmediateUse()
                },
                onReload: {
                    await vm.load()
                    homeVM.prepareForImmediateUse()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var privacyBanner: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.purple)
                Text("Keep your webhook URLs private. Anyone with access can send notifications to your devices.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var userSection: some View {
        Section {
            HomeCurlCardView(
                styledCurlExample: homeVM.attributedCurlExample(),
                isBusy: homeVM.isBusy,
                sendButtonState: sendButtonState,
                onSendTapped: handleSendTestTap
            )
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            .listRowSeparator(.hidden, edges: .bottom)

            WebhooksUserActionRow(
                curlText: homeVM.curlExample(),
                onCopy: {
                    HomeClipboard.copy(text: homeVM.curlExample())
                },
                onRegenerateTapped: {
                    confirmRotateUser = true
                }
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
            .listRowSeparator(.hidden)

            if let ts = vm.userLastUsedTimestamp, let lastUsed = Self.formattedLastUsed(ts) {
                Text(lastUsed)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden, edges: .top)
            }
        } header: {
            Text("Send to All Devices")
        }
    }

    private var devicesSection: some View {
        Section {
            if let errorMessage = vm.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
            }
            if let hint = vm.emptyStateHint, vm.errorMessage == nil {
                Text(hint)
                    .foregroundStyle(.secondary)
            }
            ForEach(vm.rows) { row in
                deviceRow(row)
            }
        } header: {
            Text("Send to a Single Device")
        } footer: {
            Text("Send notifications to a single device using its webhook.")
                .font(.footnote)
        }
    }

    private func deviceRow(_ row: DeviceEndpointRow) -> some View {
        HStack(alignment: .center, spacing: 4) {
            Button {
                selectedDevice = row
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: deviceIconName(for: row.deviceKind))
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .center)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(row.deviceLabel)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if row.isLocalDevice {
                                Text("This device")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.25))
                                    .clipShape(Capsule())
                            }
                        }
                        if let kind = row.deviceKind {
                            Text(kindDisplayName(kind))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button("Regenerate device URL", role: .destructive) {
                    Task {
                        await vm.rotateLocalDeviceWebhook(pushToken: pushTokenStore.pushTokenHex)
                        homeVM.prepareForImmediateUse()
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .foregroundStyle(.primary)
            }
        }
    }

    private func handleSendTestTap() {
        HomeFeedback.press()
        withAnimation(.easeInOut(duration: 0.2)) {
            sendButtonState = .sending
        }
        Task {
            let success = await homeVM.sendTest()
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
                await vm.load()
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

    private func kindDisplayName(_ kind: String) -> String {
        switch kind {
        case "iphone": return "iPhone"
        case "ipad": return "iPad"
        case "mac": return "Mac"
        case "tv": return "Apple TV"
        case "watch": return "Apple Watch"
        case "vision": return "Apple Vision"
        case "catalyst": return "Mac (Catalyst)"
        default: return kind.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private static func formattedLastUsed(_ iso: String) -> String? {
        let trimmed = iso.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: trimmed)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: trimmed)
        }
        guard let date else { return "Webhook was last used \(trimmed)." }
        let cal = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none
        if cal.isDateInToday(date) {
            return "Webhook was last used today at \(timeFormatter.string(from: date))."
        }
        if cal.isDateInYesterday(date) {
            return "Webhook was last used yesterday at \(timeFormatter.string(from: date))."
        }
        let dateTime = DateFormatter()
        dateTime.dateStyle = .medium
        dateTime.timeStyle = .short
        return "Webhook was last used \(dateTime.string(from: date))."
    }
}

private struct WebhooksUserActionRow: View {
    let curlText: String
    let onCopy: () -> Void
    let onRegenerateTapped: () -> Void

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

            Menu {
                Button("Regenerate user URL", role: .destructive) {
                    onRegenerateTapped()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.white)
                    )
            }
            .frame(width: 56)
        }
    }
}

struct WebhooksView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            WebhooksView()
                .environmentObject(HomeViewModel())
                .environmentObject(PushTokenStore())
        }
    }
}
