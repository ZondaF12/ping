import Foundation
import Testing
@testable import ping

private final class MockEndpointsSnapshotStore: EndpointsSnapshotStoring {
    var snapshot: PersistedEndpointsSnapshot?
    func loadSnapshot() -> PersistedEndpointsSnapshot? { snapshot }
    func saveSnapshot(_ snapshot: PersistedEndpointsSnapshot) { self.snapshot = snapshot }
    func clearSnapshot() { snapshot = nil }
}

private struct MockCloudKitForWebhooks: CloudKitServiceProtocol {
    let bundle: SecretBundle
    func fetchOrCreateSecretBundle() async throws -> SecretBundle { bundle }
    func regenerateUserSecret() async throws -> SecretBundle { bundle }
    func regenerateDeviceSecret() async throws -> SecretBundle { bundle }
}

private struct MockAPIForWebhooks: APIClientProtocol {
    var endpointsResult: EndpointResponse
    var endpointsError: Error?

    func postRegister(body: RegisterRequestBody, cloudKitToken: String) async throws {}

    func getEndpoints(cloudKitToken: String, userRecordName: String?) async throws -> EndpointResponse {
        if let endpointsError {
            throw endpointsError
        }
        return endpointsResult
    }

    func postNotify(secret: String, payload: String) async throws -> Bool { true }
}

private struct MockSecretCacheForWebhooks: SecretCacheProtocol {
    var stored: SecretBundle?
    func load() -> SecretBundle? { stored }
    func save(_ bundle: SecretBundle) -> Bool { true }
    func loadMetadata() -> SecretCacheMetadata { .empty }
    func saveMetadata(_ metadata: SecretCacheMetadata) {}
    func clear() -> Bool { true }
}

struct WebhooksEndpointsSnapshotTests {
    private let sampleBundle = SecretBundle(
        secret: "ping_usr_test",
        userRecordName: "user_test",
        deviceRecordName: "dep_test",
        cloudKitWebAuthToken: "ckwt_test",
        deviceSecret: "ping_dev_test"
    )

    private var sampleEndpoints: EndpointResponse {
        EndpointResponse(
            user: .init(lastUsedTimestamp: "2026-03-26T12:00:00.000Z", recordName: "user_test"),
            devices: [
                .init(
                    createdTimestamp: "2026-03-26T00:00:00.000Z",
                    lastSeenTimestamp: "2026-03-26T00:00:00.000Z",
                    lastUsedTimestamp: nil,
                    pushToken: String(repeating: "a", count: 64),
                    recordName: "dep_test",
                    deviceLabel: "iPhone",
                    deviceKind: "iphone",
                    apnsEnvironment: "sandbox"
                )
            ]
        )
    }

    @Test
    func persistedSnapshotRoundTripsJSON() throws {
        let snap = PersistedEndpointsSnapshot(userRecordName: "user_test", response: sampleEndpoints)
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(PersistedEndpointsSnapshot.self, from: data)
        #expect(decoded.userRecordName == "user_test")
        #expect(decoded.devices.count == 1)
        #expect(decoded.devices[0].recordName == "dep_test")
        #expect(decoded.userLastUsedTimestamp == sampleEndpoints.user.lastUsedTimestamp)
    }

    @Test
    func snapshotRowsRemapLocalWebhookFromBundle() {
        let snap = PersistedEndpointsSnapshot(userRecordName: "user_test", response: sampleEndpoints)
        let rows = snap.rows(mappingBundle: sampleBundle)
        #expect(rows.count == 1)
        #expect(rows[0].isLocalDevice == true)
        #expect(rows[0].webhookURL?.contains("ping_dev_test") == true)
        #expect(rows[0].deviceLabel == "iPhone")
    }

    @Test
    @MainActor
    func loadWithCachedSnapshotKeepsRowsWhenAPIFails() async {
        let snap = PersistedEndpointsSnapshot(userRecordName: "user_test", response: sampleEndpoints)
        let store = MockEndpointsSnapshotStore()
        store.snapshot = snap

        let vm = WebhooksViewModel(
            api: MockAPIForWebhooks(
                endpointsResult: sampleEndpoints,
                endpointsError: NSError(domain: "ping.api", code: 500, userInfo: [
                    NSLocalizedDescriptionKey: "server error",
                    PingAPIErrorInfo.httpStatusCode: 500
                ])
            ),
            cache: MockSecretCacheForWebhooks(stored: sampleBundle),
            cloudKit: MockCloudKitForWebhooks(bundle: sampleBundle),
            snapshotStore: store
        )

        await vm.load()

        #expect(vm.rows.count == 1)
        #expect(vm.rows[0].recordName == "dep_test")
        #expect(vm.isLoading == false)
        #expect(vm.isRefreshing == false)
        #expect(vm.errorMessage?.contains("refresh") == true || vm.errorMessage?.contains("Refresh") == true)
    }

    @Test
    @MainActor
    func coldLoadSavesSnapshotOnSuccess() async {
        let store = MockEndpointsSnapshotStore()
        let vm = WebhooksViewModel(
            api: MockAPIForWebhooks(endpointsResult: sampleEndpoints, endpointsError: nil),
            cache: MockSecretCacheForWebhooks(stored: sampleBundle),
            cloudKit: MockCloudKitForWebhooks(bundle: sampleBundle),
            snapshotStore: store
        )

        await vm.load()

        #expect(store.snapshot != nil)
        #expect(store.snapshot?.devices.count == 1)
        #expect(vm.rows.count == 1)
        #expect(vm.errorMessage == nil)
    }
}
