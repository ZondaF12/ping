import Foundation

struct NotifyResponse: Decodable {
    let success: Bool
}

struct RegisterRequestBody: Encodable {
    let push_token: String
    let key_digest: String
    let device_key_digest: String
    let record_name: String
    let user_record_name: String
    let device_label: String?
    let device_kind: String?
    let apns_environment: String
}

struct EndpointResponse: Decodable {
    struct User: Decodable {
        let lastUsedTimestamp: String?
        let recordName: String
    }

    struct Device: Decodable, Identifiable {
        var id: String { recordName }
        let createdTimestamp: String
        let lastSeenTimestamp: String
        let lastUsedTimestamp: String?
        let pushToken: String
        let recordName: String
        let deviceLabel: String?
        let deviceKind: String?
        let apnsEnvironment: String?
    }

    let user: User
    let devices: [Device]
}

struct SecretBundle: Codable, Equatable {
    let secret: String
    let userRecordName: String
    let deviceRecordName: String
    let cloudKitWebAuthToken: String
    let deviceSecret: String

    enum CodingKeys: String, CodingKey {
        case secret
        case userRecordName
        case deviceRecordName
        case cloudKitWebAuthToken
        case deviceSecret
    }

    init(
        secret: String,
        userRecordName: String,
        deviceRecordName: String,
        cloudKitWebAuthToken: String,
        deviceSecret: String
    ) {
        self.secret = secret
        self.userRecordName = userRecordName
        self.deviceRecordName = deviceRecordName
        self.cloudKitWebAuthToken = cloudKitWebAuthToken
        self.deviceSecret = deviceSecret
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        secret = try c.decode(String.self, forKey: .secret)
        userRecordName = try c.decode(String.self, forKey: .userRecordName)
        deviceRecordName = try c.decode(String.self, forKey: .deviceRecordName)
        cloudKitWebAuthToken = try c.decode(String.self, forKey: .cloudKitWebAuthToken)
        deviceSecret = try c.decodeIfPresent(String.self, forKey: .deviceSecret) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(secret, forKey: .secret)
        try c.encode(userRecordName, forKey: .userRecordName)
        try c.encode(deviceRecordName, forKey: .deviceRecordName)
        try c.encode(cloudKitWebAuthToken, forKey: .cloudKitWebAuthToken)
        try c.encode(deviceSecret, forKey: .deviceSecret)
    }
}

struct SecretCacheMetadata: Codable, Equatable {
    let lastSyncedAt: Date?
    let lastRegisteredPushToken: String?

    static let empty = SecretCacheMetadata(
        lastSyncedAt: nil,
        lastRegisteredPushToken: nil
    )
}
