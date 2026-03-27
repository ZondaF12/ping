import Combine
import SwiftUI

@MainActor
final class DeviceEndpointsViewModel: ObservableObject {
    @Published private(set) var rows: [DeviceEndpointRow] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isRotating = false
    @Published private(set) var errorMessage: String?
    /// Shown when the request succeeds but the server returns no device rows (not an error).
    @Published private(set) var emptyStateHint: String?

    private let api: APIClientProtocol
    private let cache: SecretCacheProtocol
    private let cloudKit: CloudKitServiceProtocol

    init(
        api: APIClientProtocol = APIClient(),
        cache: SecretCacheProtocol = SecretCache(),
        cloudKit: CloudKitServiceProtocol = CloudKitService()
    ) {
        self.api = api
        self.cache = cache
        self.cloudKit = cloudKit
    }

    func load() async {
        guard let baseBundle = cache.load(), !baseBundle.cloudKitWebAuthToken.isEmpty else {
            rows = []
            emptyStateHint = nil
            errorMessage = "Sign in to iCloud to load devices."
            return
        }
        isLoading = true
        errorMessage = nil
        emptyStateHint = nil
        defer { isLoading = false }

        // Fresh web auth token + persisted bundle before calling the API (stale tokens often yield 401).
        let bundleForRequest: SecretBundle
        do {
            bundleForRequest = try await cloudKit.fetchOrCreateSecretBundle()
            _ = cache.save(bundleForRequest)
        } catch {
            bundleForRequest = baseBundle
        }

        do {
            let response = try await loadEndpointsRefreshingTokenIfUnauthorized(bundle: bundleForRequest)
            let mappingBundle = cache.load() ?? bundleForRequest
            rows = response.devices.map { device in
                let isLocal = device.recordName == mappingBundle.deviceRecordName
                let webhook: String?
                if isLocal, !mappingBundle.deviceSecret.isEmpty {
                    webhook = "\(AppConfig.apiBase)/v1/\(mappingBundle.deviceSecret)"
                } else {
                    webhook = nil
                }
                return DeviceEndpointRow(
                    recordName: device.recordName,
                    deviceLabel: device.deviceLabel ?? device.recordName,
                    deviceKind: device.deviceKind,
                    webhookURL: webhook,
                    isLocalDevice: isLocal
                )
            }
            if rows.isEmpty {
                emptyStateHint =
                    "No devices listed yet. Finish setup on the home screen (notifications + sync), then pull to refresh."
            } else {
                emptyStateHint = nil
            }
        } catch {
            rows = []
            emptyStateHint = nil
            errorMessage = userFacingErrorMessage(for: error)
        }
    }

    /// Fetches endpoints; on **401** refreshes the CloudKit bundle (new web auth token), saves it, and retries once.
    private func loadEndpointsRefreshingTokenIfUnauthorized(bundle: SecretBundle) async throws -> EndpointResponse {
        guard !bundle.cloudKitWebAuthToken.isEmpty else {
            throw NSError(
                domain: "ping.devices",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Missing CloudKit web auth token"]
            )
        }
        do {
            return try await api.getEndpoints(
                cloudKitToken: bundle.cloudKitWebAuthToken,
                userRecordName: bundle.userRecordName
            )
        } catch {
            guard httpStatusCode(from: error) == 401 else {
                throw error
            }
            let fresh = try await cloudKit.fetchOrCreateSecretBundle()
            _ = cache.save(fresh)
            return try await api.getEndpoints(
                cloudKitToken: fresh.cloudKitWebAuthToken,
                userRecordName: fresh.userRecordName
            )
        }
    }

    private func httpStatusCode(from error: Error) -> Int? {
        let ns = error as NSError
        guard ns.domain == "ping.api" else { return nil }
        if let code = ns.userInfo[PingAPIErrorInfo.httpStatusCode] as? Int {
            return code
        }
        if (400..<600).contains(ns.code) {
            return ns.code
        }
        return nil
    }

    func rotateLocalDeviceWebhook(pushToken: String?) async {
        guard let token = pushToken, !token.isEmpty else {
            errorMessage = "Enable notifications on the home screen first."
            return
        }
        isRotating = true
        errorMessage = nil
        defer { isRotating = false }
        do {
            let bundle = try await cloudKit.regenerateDeviceSecret()
            _ = cache.save(bundle)
            try await api.postRegister(
                body: HomeViewModel.makeRegisterRequestBody(bundle: bundle, pushToken: token),
                cloudKitToken: bundle.cloudKitWebAuthToken
            )
            await load()
        } catch {
            errorMessage = userFacingRotateError(for: error)
        }
    }

    private func userFacingRotateError(for error: Error) -> String {
        #if DEBUG
        return "Couldn’t rotate device URL. \(error.localizedDescription)"
        #else
        return "Couldn’t rotate device URL. Check your connection and try again."
        #endif
    }

    private func userFacingErrorMessage(for error: Error) -> String {
        if let status = httpStatusCode(from: error) {
            switch status {
            case 401:
                return "Couldn’t verify your iCloud session. Return to the home screen to sync, then try again."
            case 404:
                return "No registered devices yet. Finish setup on the home screen (notifications enabled), then pull to refresh."
            default:
                break
            }
        }
        #if DEBUG
        return "Couldn’t load devices. \(error.localizedDescription)"
        #else
        return "Couldn’t load devices. Check your connection and try again."
        #endif
    }
}

struct DeviceEndpointRow: Identifiable {
    var id: String { recordName }
    let recordName: String
    let deviceLabel: String
    let deviceKind: String?
    let webhookURL: String?
    let isLocalDevice: Bool
}

struct DeviceEndpointsView: View {
    @EnvironmentObject private var pushTokenStore: PushTokenStore
    @StateObject private var vm = DeviceEndpointsViewModel()
    @State private var confirmRotateDevice = false

    var body: some View {
        List {
            if let errorMessage = vm.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
            }
            if let hint = vm.emptyStateHint, vm.errorMessage == nil {
                Text(hint)
                    .foregroundStyle(.secondary)
            }
            ForEach(vm.rows) { row in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(row.deviceLabel)
                            .font(.headline)
                        if row.isLocalDevice {
                            Text("This device")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.25))
                                .clipShape(Capsule())
                        }
                    }
                    if let kind = row.deviceKind {
                        Text(kindDisplayName(kind))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let url = row.webhookURL {
                        Text(url)
                            .font(.caption.monospaced())
                            .foregroundStyle(.purple)
                            .textSelection(.enabled)
                    } else {
                        Text("Webhook URL is only shown on the device that owns the secret.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if row.isLocalDevice {
                        Button("Regenerate device URL") {
                            confirmRotateDevice = true
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Devices")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if vm.isLoading || vm.isRotating {
                ProgressView()
            }
        }
        .confirmationDialog(
            "Regenerate this device’s webhook URL?",
            isPresented: $confirmRotateDevice,
            titleVisibility: .visible
        ) {
            Button("Regenerate", role: .destructive) {
                Task {
                    await vm.rotateLocalDeviceWebhook(pushToken: pushTokenStore.pushTokenHex)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The old per-device URL stops working immediately.")
        }
        .task {
            await vm.load()
        }
        .refreshable {
            await vm.load()
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
}

struct DeviceEndpointsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DeviceEndpointsView()
                .environmentObject(PushTokenStore())
        }
    }
}
