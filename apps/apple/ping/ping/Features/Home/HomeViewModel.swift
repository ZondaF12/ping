import CryptoKit
import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var secret: String = "Preparing…"
    @Published var webhookURL: String = ""
    @Published var status: String?
    @Published var registerLog: String?
    @Published var endpoints: [EndpointResponse.Device] = []
    @Published var isBusy: Bool = false
    @Published var isSyncingStartup: Bool = false

    private var bundle: SecretBundle?
    private let cloudKit: CloudKitServiceProtocol
    private let api: APIClientProtocol
    private let cache: SecretCacheProtocol

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

    func bootstrap(pushToken: String?) async {
        if let cached = cache.load() {
            applyBundle(cached)
            isSyncingStartup = true
            status = "Syncing latest data…"
        }
        do {
            let cloudBundle = try await cloudKit.fetchOrCreateSecretBundle()
            applyBundle(cloudBundle)
            _ = cache.save(cloudBundle)
            isSyncingStartup = false
            if let token = pushToken, !token.isEmpty {
                try await register(pushToken: token)
            } else {
                status = "Waiting for APNs token. Accept notification permission and re-open app."
            }
            try await refreshEndpoints()
        } catch {
            isSyncingStartup = false
            if bundle != nil {
                status = "Using cached secret. Cloud sync failed: \(error.localizedDescription)"
            } else {
                status = "Startup failed: \(error.localizedDescription)"
            }
        }
    }

    func register(pushToken: String?) async throws {
        guard let bundle else { return }
        guard let token = pushToken, !token.isEmpty else {
            status = "No APNs token yet. Check push capabilities/signing."
            return
        }

        isBusy = true
        defer { isBusy = false }

        let body = RegisterRequestBody(
            push_token: token,
            user_key_digest: Self.digest(bundle.secret),
            key_digest: Self.digest(bundle.secret),
            record_name: bundle.deviceRecordName,
            user_record_name: bundle.userRecordName
        )

        try await api.postRegister(
            body: body,
            cloudKitToken: bundle.cloudKitWebAuthToken
        )
        registerLog = "\(Self.now()): register -> OK"
        status = "Registered device endpoint."
    }

    func sendTest() async {
        guard let bundle else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let payload = NotifyPayload(
                title: "Ping test",
                subtitle: "From SwiftUI",
                message: "If you see this, the webhook works.",
                url: "https://expo.dev"
            )
            let code = try await api.postNotify(secret: bundle.secret, payload: payload)
            status = "Sent (\(code))."
        } catch {
            status = "Send failed: \(error.localizedDescription)"
        }
    }

    func refreshEndpoints() async throws {
        guard let bundle else { return }
        let response = try await api.getEndpoints(cloudKitToken: bundle.cloudKitWebAuthToken)
        endpoints = response.devices
    }

    func curlExample() -> String {
        let payload = NotifyPayload(
            title: "Ping test",
            subtitle: "From SwiftUI",
            message: "If you see this, the webhook works.",
            url: "https://expo.dev"
        )
        let jsonData = try? JSONEncoder().encode(payload)
        let json = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return """
        curl -X POST \"\(webhookURL)\" \\
          -H \"Content-Type: application/json\" \\
          -d '\(json)'
        """
    }

    private static func digest(_ raw: String) -> String {
        let bytes = SHA256.hash(data: Data(raw.utf8))
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func now() -> String {
        let f = DateFormatter()
        f.timeStyle = .medium
        return f.string(from: Date())
    }

    private func applyBundle(_ bundle: SecretBundle) {
        self.bundle = bundle
        self.secret = bundle.secret
        self.webhookURL = "\(AppConfig.apiBase)/v1/\(bundle.secret)"
    }
}
