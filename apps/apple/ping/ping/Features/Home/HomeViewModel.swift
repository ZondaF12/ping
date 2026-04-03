import CryptoKit
import Foundation
import Combine
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var secret: String = "ping_usr_pending"
    @Published var webhookURL: String = ""
    @Published var isBusy: Bool = false

    private(set) var currentBundle: SecretBundle?

    private var metadata: SecretCacheMetadata = .empty
    private var isBackgroundSyncing = false
    private let cloudKit: CloudKitServiceProtocol
    private let api: APIClientProtocol
    private let cache: SecretCacheProtocol
    private let minSyncInterval: TimeInterval = 60 * 15

    init(
        cloudKit: CloudKitServiceProtocol,
        api: APIClientProtocol,
        cache: SecretCacheProtocol
    ) {
        self.cloudKit = cloudKit
        self.api = api
        self.cache = cache
    }

    convenience init() {
        self.init(
            cloudKit: CloudKitService(),
            api: APIClient(),
            cache: SecretCache()
        )
    }

    func prepareForImmediateUse() {
        metadata = cache.loadMetadata()
        if let cached = cache.load() {
            applyBundle(cached)
        }
    }

    /// Loads cache then attempts CloudKit sync (used by tests and cold start flows).
    func bootstrap(pushToken: String?) async {
        prepareForImmediateUse()
        await syncInBackground(pushToken: pushToken)
    }

    func syncInBackground(pushToken: String?) async {
        if isBackgroundSyncing {
            return
        }
        if !shouldRunCloudSync() {
            if let token = pushToken, shouldRegister(token: token) {
                try? await registerIfNeededSilently(pushToken: token, force: false)
            }
            return
        }

        isBackgroundSyncing = true
        defer { isBackgroundSyncing = false }
        do {
            let cloudBundle = try await cloudKit.fetchOrCreateSecretBundle()
            applyBundle(cloudBundle)
            _ = cache.save(cloudBundle)
            metadata = SecretCacheMetadata(
                lastSyncedAt: Date(),
                lastRegisteredPushToken: metadata.lastRegisteredPushToken
            )
            cache.saveMetadata(metadata)
            if let token = pushToken, !token.isEmpty {
                try? await registerIfNeededSilently(pushToken: token, force: false)
            }
        } catch {
            // keep startup quiet; user can still use cached secret
        }
    }

    func register(pushToken: String?) async throws {
        guard let bundle = currentBundle else { return }
        guard let token = pushToken, !token.isEmpty else {
            return
        }

        isBusy = true
        defer { isBusy = false }

        let body = Self.makeRegisterRequestBody(bundle: bundle, pushToken: token)

        try await api.postRegister(
            body: body,
            cloudKitToken: bundle.cloudKitWebAuthToken
        )
        metadata = SecretCacheMetadata(
            lastSyncedAt: metadata.lastSyncedAt,
            lastRegisteredPushToken: token
        )
        cache.saveMetadata(metadata)
    }

    /// Regenerates the user-level webhook secret in CloudKit and re-registers with the API.
    func rotateUserWebhook(pushToken: String?) async throws {
        guard let token = pushToken, !token.isEmpty else {
            return
        }
        isBusy = true
        defer { isBusy = false }
        let bundle = try await cloudKit.regenerateUserSecret()
        applyBundle(bundle)
        _ = cache.save(bundle)
        try await api.postRegister(
            body: Self.makeRegisterRequestBody(bundle: bundle, pushToken: token),
            cloudKitToken: bundle.cloudKitWebAuthToken
        )
        metadata = SecretCacheMetadata(
            lastSyncedAt: metadata.lastSyncedAt,
            lastRegisteredPushToken: token
        )
        cache.saveMetadata(metadata)
    }

    func sendTest() async -> Bool {
        guard let bundle = currentBundle else {
            return false
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let payload = "Hello, World! 🎉"
            return try await api.postNotify(secret: bundle.secret, payload: payload)
        } catch {
            return false
        }
    }

    /// Per-device webhook URL for the locally registered device (empty if no bundle or device secret).
    var deviceWebhookURL: String {
        guard let bundle = currentBundle, !bundle.deviceSecret.isEmpty else {
            return ""
        }
        return "\(AppConfig.apiBase)/v1/\(bundle.deviceSecret)"
    }

    /// Raw per-device webhook secret (empty if no bundle or no device secret).
    var deviceSecret: String {
        guard let bundle = currentBundle, !bundle.deviceSecret.isEmpty else {
            return ""
        }
        return bundle.deviceSecret
    }

    func sendDeviceTest() async -> Bool {
        guard let bundle = currentBundle, !bundle.deviceSecret.isEmpty else {
            return false
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let payload = "Hello, World! 🎉"
            return try await api.postNotify(secret: bundle.deviceSecret, payload: payload)
        } catch {
            return false
        }
    }

    func curlExample() -> String {
        let payload = "Hello, World! 🎉"
        return """
        curl -X POST \(webhookURL) \\
          -d '\(payload)'
        """
    }

    /// Syntax-highlighted curl for cards (home + webhooks settings).
    func attributedCurlExample() -> AttributedString {
        let raw = curlExample()
        var styled = AttributedString(raw)
        styled.foregroundColor = .gray
        if let urlRange = styled.range(of: webhookURL), !webhookURL.isEmpty {
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

    func deviceCurlExample() -> String {
        let payload = "Hello, World! 🎉"
        let url = deviceWebhookURL
        guard !url.isEmpty else {
            return ""
        }
        return """
        curl -X POST \(url) \\
          -d '\(payload)'
        """
    }

    /// Syntax-highlighted curl for the per-device webhook (local device only).
    func attributedDeviceCurlExample() -> AttributedString {
        let raw = deviceCurlExample()
        var styled = AttributedString(raw)
        styled.foregroundColor = .gray
        let url = deviceWebhookURL
        if let urlRange = styled.range(of: url), !url.isEmpty {
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

    static func makeRegisterRequestBody(bundle: SecretBundle, pushToken: String) -> RegisterRequestBody {
        RegisterRequestBody(
            push_token: pushToken,
            key_digest: digest(bundle.secret),
            device_key_digest: digest(bundle.deviceSecret),
            record_name: bundle.deviceRecordName,
            user_record_name: bundle.userRecordName,
            device_label: DeviceInfo.deviceLabel,
            device_kind: DeviceInfo.deviceKind,
            apns_environment: DeviceInfo.apnsEnvironment
        )
    }

    private static func digest(_ raw: String) -> String {
        let bytes = SHA256.hash(data: Data(raw.utf8))
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func shouldRunCloudSync(now: Date = Date()) -> Bool {
        guard let last = metadata.lastSyncedAt else {
            return true
        }
        return now.timeIntervalSince(last) >= minSyncInterval
    }

    private func shouldRegister(token: String) -> Bool {
        metadata.lastRegisteredPushToken != token
    }

    private func registerIfNeededSilently(pushToken: String, force: Bool) async throws {
        guard let bundle = currentBundle else { return }
        if !force && !shouldRegister(token: pushToken) {
            return
        }
        let body = Self.makeRegisterRequestBody(bundle: bundle, pushToken: pushToken)
        try await api.postRegister(
            body: body,
            cloudKitToken: bundle.cloudKitWebAuthToken
        )
        metadata = SecretCacheMetadata(
            lastSyncedAt: metadata.lastSyncedAt,
            lastRegisteredPushToken: pushToken
        )
        cache.saveMetadata(metadata)
    }

    private func applyBundle(_ bundle: SecretBundle) {
        self.currentBundle = bundle
        self.secret = bundle.secret
        self.webhookURL = "\(AppConfig.apiBase)/v1/\(bundle.secret)"
    }

}
