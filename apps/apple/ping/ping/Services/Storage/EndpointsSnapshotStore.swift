import Foundation

/// Persisted device rows from the last successful `/v1/me/endpoints` response (no webhook URLs).
struct PersistedDevice: Codable, Equatable {
    let recordName: String
    let deviceLabel: String
    let deviceKind: String?
    let lastSeenTimestamp: String?
    let lastUsedTimestamp: String?

    init(device: EndpointResponse.Device) {
        recordName = device.recordName
        deviceLabel = device.deviceLabel ?? device.recordName
        deviceKind = device.deviceKind
        lastSeenTimestamp = device.lastSeenTimestamp
        lastUsedTimestamp = device.lastUsedTimestamp
    }
}

/// Snapshot keyed by `userRecordName`; remap rows with current `SecretBundle` after load.
struct PersistedEndpointsSnapshot: Codable, Equatable {
    var version: Int
    let userRecordName: String
    let savedAt: Date
    let userLastUsedTimestamp: String?
    let devices: [PersistedDevice]

    enum CodingKeys: String, CodingKey {
        case version
        case userRecordName
        case savedAt
        case userLastUsedTimestamp
        case devices
    }

    init(userRecordName: String, response: EndpointResponse) {
        version = 1
        self.userRecordName = userRecordName
        savedAt = Date()
        userLastUsedTimestamp = response.user.lastUsedTimestamp
        devices = response.devices.map { PersistedDevice(device: $0) }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        userRecordName = try c.decode(String.self, forKey: .userRecordName)
        savedAt = try c.decode(Date.self, forKey: .savedAt)
        userLastUsedTimestamp = try c.decodeIfPresent(String.self, forKey: .userLastUsedTimestamp)
        devices = try c.decode([PersistedDevice].self, forKey: .devices)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(userRecordName, forKey: .userRecordName)
        try c.encode(savedAt, forKey: .savedAt)
        try c.encodeIfPresent(userLastUsedTimestamp, forKey: .userLastUsedTimestamp)
        try c.encode(devices, forKey: .devices)
    }

    func rows(mappingBundle: SecretBundle) -> [DeviceEndpointRow] {
        devices.map { d in
            let isLocal = d.recordName == mappingBundle.deviceRecordName
            let webhook: String?
            if isLocal, !mappingBundle.deviceSecret.isEmpty {
                webhook = "\(AppConfig.apiBase)/v1/\(mappingBundle.deviceSecret)"
            } else {
                webhook = nil
            }
            return DeviceEndpointRow(
                recordName: d.recordName,
                deviceLabel: d.deviceLabel,
                deviceKind: d.deviceKind,
                webhookURL: webhook,
                isLocalDevice: isLocal,
                lastSeenTimestamp: d.lastSeenTimestamp,
                lastUsedTimestamp: d.lastUsedTimestamp
            )
        }
    }
}

protocol EndpointsSnapshotStoring: AnyObject {
    func loadSnapshot() -> PersistedEndpointsSnapshot?
    func saveSnapshot(_ snapshot: PersistedEndpointsSnapshot)
    func clearSnapshot()
}

final class EndpointsSnapshotStore: EndpointsSnapshotStoring {
    private let key = "ping.endpoints.snapshot.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSnapshot() -> PersistedEndpointsSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PersistedEndpointsSnapshot.self, from: data)
    }

    func saveSnapshot(_ snapshot: PersistedEndpointsSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    func clearSnapshot() {
        defaults.removeObject(forKey: key)
    }
}
