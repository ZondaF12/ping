import CloudKit
import Foundation

protocol CloudKitServiceProtocol {
    func fetchOrCreateSecretBundle() async throws -> SecretBundle
}

struct CloudKitService: CloudKitServiceProtocol {
    private let container = CKContainer.default()
    private let database = CKContainer.default().privateCloudDatabase

    func fetchOrCreateSecretBundle() async throws -> SecretBundle {
        let userRecordID = try await fetchUserRecordID()
        let userRecordName = userRecordID.recordName
        let secretRecordID = CKRecord.ID(recordName: "usr_\(userRecordName)")
        let installationId = loadOrCreateInstallationId()
        let deviceRecordName = "dep_\(installationId)"

        let secretRecord: CKRecord
        do {
            secretRecord = try await fetchRecord(with: secretRecordID)
        } catch {
            let created = CKRecord(recordType: "SecretRecord", recordID: secretRecordID)
            created["secret"] = generatedSecret() as CKRecordValue
            created["user_record_name"] = userRecordName as CKRecordValue
            created["created_timestamp"] = Date() as CKRecordValue
            secretRecord = try await saveRecord(created)
        }

        guard let secret = secretRecord["secret"] as? String else {
            throw NSError(domain: "ping.ck", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "SecretRecord missing secret"
            ])
        }

        let deviceID = CKRecord.ID(recordName: deviceRecordName)
        let deviceRecord: CKRecord
        do {
            deviceRecord = try await fetchRecord(with: deviceID)
        } catch {
            deviceRecord = CKRecord(recordType: "DeviceRecord", recordID: deviceID)
            deviceRecord["created_timestamp"] = Date() as CKRecordValue
        }
        deviceRecord["record_name"] = deviceRecordName as CKRecordValue
        deviceRecord["installation_id"] = installationId as CKRecordValue
        deviceRecord["platform"] = "ios" as CKRecordValue
        deviceRecord["last_seen_timestamp"] = Date() as CKRecordValue
        _ = try await saveRecord(deviceRecord)

        let cloudKitWebAuthToken = try await fetchWebAuthToken()
        return SecretBundle(
            secret: secret,
            userRecordName: userRecordName,
            deviceRecordName: deviceRecordName,
            cloudKitWebAuthToken: cloudKitWebAuthToken
        )
    }

    private func fetchUserRecordID() async throws -> CKRecord.ID {
        try await withCheckedThrowingContinuation { continuation in
            container.fetchUserRecordID { id, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let id else {
                    continuation.resume(throwing: NSError(
                        domain: "ping.ck",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "No iCloud user record"]
                    ))
                    return
                }
                continuation.resume(returning: id)
            }
        }
    }

    private func fetchRecord(with id: CKRecord.ID) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            database.fetch(withRecordID: id) { record, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let record else {
                    continuation.resume(throwing: NSError(
                        domain: "ping.ck",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Record not found"]
                    ))
                    return
                }
                continuation.resume(returning: record)
            }
        }
    }

    private func saveRecord(_ record: CKRecord) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            database.save(record) { saved, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let saved else {
                    continuation.resume(throwing: NSError(
                        domain: "ping.ck",
                        code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "Save failed"]
                    ))
                    return
                }
                continuation.resume(returning: saved)
            }
        }
    }

    private func fetchWebAuthToken() async throws -> String {
        let apiToken = AppConfig.cloudKitApiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiToken.isEmpty else {
            throw NSError(
                domain: "ping.ck",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Missing PING_CLOUDKIT_API_TOKEN"]
            )
        }

        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchWebAuthTokenOperation(apiToken: apiToken)
            operation.fetchWebAuthTokenResultBlock = { result in
                switch result {
                case .success(let token):
                    guard !token.isEmpty else {
                        continuation.resume(throwing: NSError(
                            domain: "ping.ck",
                            code: 6,
                            userInfo: [NSLocalizedDescriptionKey: "CloudKit web auth token missing"]
                        ))
                        return
                    }
                    continuation.resume(returning: token)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            self.database.add(operation)
        }
    }

    private func generatedSecret() -> String {
        let bytes = (0..<24).map { _ in UInt8.random(in: 0...255) }
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        return "br_usr_\(hex)"
    }

    private func loadOrCreateInstallationId() -> String {
        let key = "ping.installation_id"
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        UserDefaults.standard.set(created, forKey: key)
        return created
    }
}
