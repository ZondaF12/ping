import Foundation
import Security

protocol SecretCacheProtocol {
    func load() -> SecretBundle?
    func save(_ bundle: SecretBundle) -> Bool
    func clear() -> Bool
}

struct SecretCache: SecretCacheProtocol {
    private let service = "ping.secretbundle.v1"
    private let account = "default"

    func load() -> SecretBundle? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(SecretBundle.self, from: data)
    }

    func save(_ bundle: SecretBundle) -> Bool {
        guard let data = try? JSONEncoder().encode(bundle) else {
            return false
        }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }

        let create = baseQuery.merging(update) { _, new in new }
        let addStatus = SecItemAdd(create as CFDictionary, nil)
        return addStatus == errSecSuccess
    }

    func clear() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
