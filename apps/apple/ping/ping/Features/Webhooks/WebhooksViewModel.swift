import Combine
import Foundation

@MainActor
final class WebhooksViewModel: ObservableObject {
    @Published private(set) var rows: [DeviceEndpointRow] = []
    @Published private(set) var userWebhookURL: String = ""
    @Published private(set) var userLastUsedTimestamp: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var isRotating = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var emptyStateHint: String?

    private let api: APIClientProtocol
    private let cache: SecretCacheProtocol
    private let cloudKit: CloudKitServiceProtocol
    private let snapshotStore: EndpointsSnapshotStoring

    init(
        api: APIClientProtocol = APIClient(),
        cache: SecretCacheProtocol = SecretCache(),
        cloudKit: CloudKitServiceProtocol = CloudKitService(),
        snapshotStore: EndpointsSnapshotStoring = EndpointsSnapshotStore()
    ) {
        self.api = api
        self.cache = cache
        self.cloudKit = cloudKit
        self.snapshotStore = snapshotStore
    }

    func load() async {
        applyUserWebhookFromCache()

        guard let baseBundle = cache.load(), !baseBundle.cloudKitWebAuthToken.isEmpty else {
            rows = []
            userLastUsedTimestamp = nil
            emptyStateHint = nil
            errorMessage = "Sign in to iCloud to load devices."
            isLoading = false
            isRefreshing = false
            return
        }

        let hadSnapshotForUser: Bool
        if let snapshot = snapshotStore.loadSnapshot(), snapshot.userRecordName == baseBundle.userRecordName {
            rows = snapshot.rows(mappingBundle: baseBundle)
            userLastUsedTimestamp = snapshot.userLastUsedTimestamp
            hadSnapshotForUser = true
            errorMessage = nil
            if rows.isEmpty {
                emptyStateHint =
                    "No devices listed yet. Finish setup on the home screen (notifications + sync), then pull to refresh."
            } else {
                emptyStateHint = nil
            }
        } else {
            userLastUsedTimestamp = nil
            rows = []
            hadSnapshotForUser = false
            emptyStateHint = nil
            errorMessage = nil
        }

        let useBlockingLoader = !hadSnapshotForUser
        isRefreshing = true
        if useBlockingLoader {
            isLoading = true
        }
        defer {
            isLoading = false
            isRefreshing = false
        }

        let bundleForRequest: SecretBundle
        do {
            bundleForRequest = try await cloudKit.fetchOrCreateSecretBundle()
            _ = cache.save(bundleForRequest)
        } catch {
            bundleForRequest = baseBundle
        }

        let mappingBundleAfterCK = cache.load() ?? bundleForRequest

        do {
            let response = try await loadEndpointsRefreshingTokenIfUnauthorized(bundle: bundleForRequest)
            userLastUsedTimestamp = response.user.lastUsedTimestamp
            let mappingBundle = cache.load() ?? bundleForRequest
            applyUserWebhook(from: mappingBundle)
            rows = mapDevicesToRows(response.devices, mappingBundle: mappingBundle)
            snapshotStore.saveSnapshot(
                PersistedEndpointsSnapshot(userRecordName: mappingBundle.userRecordName, response: response)
            )
            errorMessage = nil
            if rows.isEmpty {
                emptyStateHint =
                    "No devices listed yet. Finish setup on the home screen (notifications + sync), then pull to refresh."
            } else {
                emptyStateHint = nil
            }
        } catch {
            if hadSnapshotForUser,
               let snap = snapshotStore.loadSnapshot(),
               snap.userRecordName == baseBundle.userRecordName
            {
                rows = snap.rows(mappingBundle: mappingBundleAfterCK)
                userLastUsedTimestamp = snap.userLastUsedTimestamp
                if rows.isEmpty {
                    emptyStateHint =
                        "No devices listed yet. Finish setup on the home screen (notifications + sync), then pull to refresh."
                }
                errorMessage = userFacingRefreshError(for: error)
            } else {
                rows = []
                userLastUsedTimestamp = nil
                emptyStateHint = nil
                errorMessage = userFacingErrorMessage(for: error)
            }
        }
    }

    private func mapDevicesToRows(
        _ devices: [EndpointResponse.Device],
        mappingBundle: SecretBundle
    ) -> [DeviceEndpointRow] {
        devices.map { device in
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
                isLocalDevice: isLocal,
                lastSeenTimestamp: device.lastSeenTimestamp,
                lastUsedTimestamp: device.lastUsedTimestamp
            )
        }
    }

    private func applyUserWebhookFromCache() {
        guard let bundle = cache.load() else {
            userWebhookURL = ""
            return
        }
        applyUserWebhook(from: bundle)
    }

    private func applyUserWebhook(from bundle: SecretBundle) {
        guard !bundle.secret.isEmpty else {
            userWebhookURL = ""
            return
        }
        userWebhookURL = "\(AppConfig.apiBase)/v1/\(bundle.secret)"
    }

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

    private func userFacingRefreshError(for error: Error) -> String {
        #if DEBUG
        return "Couldn’t refresh devices (showing last load). \(userFacingErrorMessage(for: error))"
        #else
        return "Couldn’t refresh devices. Showing the last successful load."
        #endif
    }
}

struct DeviceEndpointRow: Identifiable, Hashable {
    var id: String { recordName }
    let recordName: String
    let deviceLabel: String
    let deviceKind: String?
    let webhookURL: String?
    let isLocalDevice: Bool
    let lastSeenTimestamp: String?
    let lastUsedTimestamp: String?
}
