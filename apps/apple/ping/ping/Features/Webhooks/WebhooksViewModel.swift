import Combine
import Foundation

@MainActor
final class WebhooksViewModel: ObservableObject {
    @Published private(set) var rows: [DeviceEndpointRow] = []
    @Published private(set) var userWebhookURL: String = ""
    @Published private(set) var userLastUsedTimestamp: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isRotating = false
    @Published private(set) var errorMessage: String?
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
        applyUserWebhookFromCache()
        userLastUsedTimestamp = nil

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

        let bundleForRequest: SecretBundle
        do {
            bundleForRequest = try await cloudKit.fetchOrCreateSecretBundle()
            _ = cache.save(bundleForRequest)
        } catch {
            bundleForRequest = baseBundle
        }

        do {
            let response = try await loadEndpointsRefreshingTokenIfUnauthorized(bundle: bundleForRequest)
            userLastUsedTimestamp = response.user.lastUsedTimestamp
            let mappingBundle = cache.load() ?? bundleForRequest
            applyUserWebhook(from: mappingBundle)
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
                    isLocalDevice: isLocal,
                    lastSeenTimestamp: device.lastSeenTimestamp,
                    lastUsedTimestamp: device.lastUsedTimestamp
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
