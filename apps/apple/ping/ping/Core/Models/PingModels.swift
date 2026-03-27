import Foundation

struct NotifyResponse: Decodable {
    let success: Bool
}

struct RegisterRequestBody: Encodable {
    let push_token: String
    let user_key_digest: String
    let key_digest: String
    let record_name: String
    let user_record_name: String
}

struct EndpointResponse: Decodable {
    struct User: Decodable {
        let last_used_timestamp: String?
        let record_name: String
    }

    struct Device: Decodable, Identifiable {
        var id: String { record_name }
        let created_timestamp: String
        let last_seen_timestamp: String
        let last_used_timestamp: String?
        let push_token: String
        let record_name: String
    }

    let user: User
    let devices: [Device]
}

struct SecretBundle: Codable, Equatable {
    let secret: String
    let userRecordName: String
    let deviceRecordName: String
    let cloudKitWebAuthToken: String
}

struct SecretCacheMetadata: Codable, Equatable {
    let lastSyncedAt: Date?
    let lastRegisteredPushToken: String?

    static let empty = SecretCacheMetadata(
        lastSyncedAt: nil,
        lastRegisteredPushToken: nil
    )
}
