import Foundation
import Testing
@testable import ping

private struct MockCloudKitService: CloudKitServiceProtocol {
    let bundle: SecretBundle
    let error: Error?

    func fetchOrCreateSecretBundle() async throws -> SecretBundle {
        if let error {
            throw error
        }
        return bundle
    }
}

private struct MockAPIClient: APIClientProtocol {
    var registerError: Error?
    var endpointsResult: EndpointResponse
    var endpointsError: Error?
    var notifySuccess: Bool = true
    var notifyError: Error?

    func postRegister(body: RegisterRequestBody, cloudKitToken: String) async throws {
        if let registerError {
            throw registerError
        }
    }

    func getEndpoints(cloudKitToken: String) async throws -> EndpointResponse {
        if let endpointsError {
            throw endpointsError
        }
        return endpointsResult
    }

    func postNotify(secret: String, payload: String) async throws -> Bool {
        if let notifyError {
            throw notifyError
        }
        return notifySuccess
    }
}

private struct MockSecretCache: SecretCacheProtocol {
    var stored: SecretBundle?
    var metadata: SecretCacheMetadata = .empty

    func load() -> SecretBundle? {
        stored
    }

    func save(_ bundle: SecretBundle) -> Bool {
        true
    }

    func loadMetadata() -> SecretCacheMetadata {
        metadata
    }

    func saveMetadata(_ metadata: SecretCacheMetadata) {}

    func clear() -> Bool {
        true
    }
}

private actor RegisterCounter {
    private(set) var count = 0
    func increment() { count += 1 }
    func value() -> Int { count }
}

private struct CountingAPIClient: APIClientProtocol {
    let counter: RegisterCounter
    let endpointsResult: EndpointResponse

    func postRegister(body: RegisterRequestBody, cloudKitToken: String) async throws {
        await counter.increment()
    }

    func getEndpoints(cloudKitToken: String) async throws -> EndpointResponse {
        endpointsResult
    }

    func postNotify(secret: String, payload: String) async throws -> Bool {
        true
    }
}

struct HomeViewModelTests {
    private let sampleBundle = SecretBundle(
        secret: "br_usr_test",
        userRecordName: "user_test",
        deviceRecordName: "dep_test",
        cloudKitWebAuthToken: "ckwt_test"
    )

    private let sampleEndpoints = EndpointResponse(
        user: .init(last_used_timestamp: nil, record_name: "user_test"),
        devices: [
            .init(
                created_timestamp: "2026-03-26T00:00:00.000Z",
                last_seen_timestamp: "2026-03-26T00:00:00.000Z",
                last_used_timestamp: nil,
                push_token: "a".repeating(count: 64),
                record_name: "dep_test"
            )
        ]
    )

    @Test
    @MainActor
    func prepareForImmediateUseLoadsCachedBundleImmediately() async {
        let cached = SecretBundle(
            secret: "br_usr_cached",
            userRecordName: "user_cached",
            deviceRecordName: "dep_cached",
            cloudKitWebAuthToken: "ckwt_cached"
        )
        let vm = HomeViewModel(
            cloudKit: MockCloudKitService(bundle: sampleBundle, error: nil),
            api: MockAPIClient(
                endpointsResult: sampleEndpoints
            ),
            cache: MockSecretCache(stored: cached)
        )

        vm.prepareForImmediateUse()

        #expect(vm.secret == cached.secret)
        #expect(vm.webhookURL.contains(cached.secret))
    }

    @Test
    @MainActor
    func sendTestWithoutBundleKeepsViewModelStable() async {
        let vm = HomeViewModel(
            cloudKit: MockCloudKitService(bundle: sampleBundle, error: nil),
            api: MockAPIClient(
                endpointsResult: sampleEndpoints
            ),
            cache: MockSecretCache()
        )
        let success = await vm.sendTest()

        #expect(success == false)
        #expect(vm.secret == "br_usr_pending")
        #expect(vm.webhookURL.isEmpty)
        #expect(vm.isBusy == false)
    }

    @Test
    @MainActor
    func sendTestSuccessCompletesWithoutBusyLeak() async {
        let vm = HomeViewModel(
            cloudKit: MockCloudKitService(bundle: sampleBundle, error: nil),
            api: MockAPIClient(
                endpointsResult: sampleEndpoints,
                notifySuccess: true
            ),
            cache: MockSecretCache()
        )
        vm.prepareForImmediateUse()
        await vm.syncInBackground(pushToken: String(repeating: "b", count: 64))
        let success = await vm.sendTest()

        #expect(success == true)
        #expect(vm.secret == sampleBundle.secret)
        #expect(vm.webhookURL.contains(sampleBundle.secret))
        #expect(vm.isBusy == false)
    }

    @Test
    @MainActor
    func sendTestFailureReturnsFalseAndResetsBusy() async {
        struct NotifyFailure: Error {}
        let vm = HomeViewModel(
            cloudKit: MockCloudKitService(bundle: sampleBundle, error: nil),
            api: MockAPIClient(
                registerError: nil,
                endpointsResult: sampleEndpoints,
                endpointsError: nil,
                notifySuccess: false,
                notifyError: NotifyFailure()
            ),
            cache: MockSecretCache()
        )
        vm.prepareForImmediateUse()
        await vm.syncInBackground(pushToken: String(repeating: "c", count: 64))

        let success = await vm.sendTest()

        #expect(success == false)
        #expect(vm.isBusy == false)
    }

    @Test
    @MainActor
    func bootstrapWithCacheShowsCachedSecretImmediately() async {
        let cached = SecretBundle(
            secret: "br_usr_cached",
            userRecordName: "user_cached",
            deviceRecordName: "dep_cached",
            cloudKitWebAuthToken: "ckwt_cached"
        )
        let vm = HomeViewModel(
            cloudKit: MockCloudKitService(bundle: sampleBundle, error: nil),
            api: MockAPIClient(endpointsResult: sampleEndpoints),
            cache: MockSecretCache(stored: cached)
        )

        await vm.bootstrap(pushToken: nil)

        #expect(vm.secret == sampleBundle.secret)
        #expect(vm.webhookURL.contains(sampleBundle.secret))
    }

    @Test
    @MainActor
    func bootstrapCloudKitFailureUsesCache() async {
        struct SampleError: Error {}
        let cached = SecretBundle(
            secret: "br_usr_cached",
            userRecordName: "user_cached",
            deviceRecordName: "dep_cached",
            cloudKitWebAuthToken: "ckwt_cached"
        )
        let vm = HomeViewModel(
            cloudKit: MockCloudKitService(bundle: sampleBundle, error: SampleError()),
            api: MockAPIClient(endpointsResult: sampleEndpoints),
            cache: MockSecretCache(stored: cached)
        )

        await vm.bootstrap(pushToken: nil)

        #expect(vm.secret == cached.secret)
    }

    @Test
    @MainActor
    func syncInBackgroundSkipsRegisterWhenTokenAlreadyRegisteredAndFresh() async {
        let counter = RegisterCounter()
        let token = String(repeating: "d", count: 64)
        let metadata = SecretCacheMetadata(
            lastSyncedAt: Date(),
            lastRegisteredPushToken: token
        )
        let vm = HomeViewModel(
            cloudKit: MockCloudKitService(bundle: sampleBundle, error: nil),
            api: CountingAPIClient(counter: counter, endpointsResult: sampleEndpoints),
            cache: MockSecretCache(stored: sampleBundle, metadata: metadata)
        )

        vm.prepareForImmediateUse()
        await vm.syncInBackground(pushToken: token)

        #expect(await counter.value() == 0)
    }
}

private extension String {
    func repeating(count: Int) -> String {
        String(repeating: self, count: count)
    }
}
