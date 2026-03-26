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
    var notifyCode: Int = 202
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

    func postNotify(secret: String, payload: NotifyPayload) async throws -> Int {
        if let notifyError {
            throw notifyError
        }
        return notifyCode
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
    func bootstrapWithoutTokenShowsWaitingStatus() async {
        let vm = HomeViewModel(
            cloudKit: MockCloudKitService(bundle: sampleBundle, error: nil),
            api: MockAPIClient(
                endpointsResult: sampleEndpoints
            )
        )

        await vm.bootstrap(pushToken: nil)

        #expect(vm.secret == sampleBundle.secret)
        #expect(vm.status?.contains("Waiting for APNs token") == true)
    }

    @Test
    @MainActor
    func registerWithEmptyTokenShowsNoTokenStatus() async throws {
        let vm = HomeViewModel(
            cloudKit: MockCloudKitService(bundle: sampleBundle, error: nil),
            api: MockAPIClient(
                endpointsResult: sampleEndpoints
            )
        )
        await vm.bootstrap(pushToken: nil)
        try await vm.register(pushToken: "")

        #expect(vm.status?.contains("No APNs token yet") == true)
    }

    @Test
    @MainActor
    func sendTestSuccessUpdatesStatus() async {
        let vm = HomeViewModel(
            cloudKit: MockCloudKitService(bundle: sampleBundle, error: nil),
            api: MockAPIClient(
                endpointsResult: sampleEndpoints,
                notifyCode: 202
            )
        )
        await vm.bootstrap(pushToken: String(repeating: "b", count: 64))
        await vm.sendTest()

        #expect(vm.status == "Sent (202).")
    }

    @Test
    @MainActor
    func refreshEndpointsMapsDevices() async throws {
        let vm = HomeViewModel(
            cloudKit: MockCloudKitService(bundle: sampleBundle, error: nil),
            api: MockAPIClient(
                endpointsResult: sampleEndpoints
            )
        )
        await vm.bootstrap(pushToken: String(repeating: "c", count: 64))
        try await vm.refreshEndpoints()

        #expect(vm.endpoints.count == 1)
        #expect(vm.endpoints.first?.record_name == "dep_test")
    }
}

private extension String {
    func repeating(count: Int) -> String {
        String(repeating: self, count: count)
    }
}
