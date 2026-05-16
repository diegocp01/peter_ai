import Foundation
import Security

enum KeychainStore {
    private static let service = "PeterAI"
    private static let account = "OpenAIAPIKey"
    private static let defaultsKey = "PeterAI.OpenAIAPIKey"

    static func loadAPIKey() -> String? {
        if
            let key = UserDefaults.standard.string(forKey: defaultsKey),
            !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return key
        }

        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if
            status == errSecSuccess,
            let data = item as? Data,
            let key = String(data: data, encoding: .utf8),
            !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return key
        }
        return nil
    }

    static func saveAPIKey(_ apiKey: String) throws {
        publishAPIKeyToCloud(apiKey)

        let data = Data(apiKey.utf8)
        let updateStatus = SecItemUpdate(
            baseQuery() as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        if updateStatus == errSecSuccess {
            UserDefaults.standard.set(apiKey, forKey: defaultsKey)
            return
        }

        guard updateStatus == errSecItemNotFound else {
            UserDefaults.standard.set(apiKey, forKey: defaultsKey)
            throw KeychainError.unhandledStatus(updateStatus)
        }

        var item = baseQuery()
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)

        UserDefaults.standard.set(apiKey, forKey: defaultsKey)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    static func publishAPIKeyToCloud(_ apiKey: String) {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        UserDefaults.standard.set(trimmed, forKey: defaultsKey)
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum KeychainError: LocalizedError {
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unhandledStatus(let status):
            "Keychain returned status \(status)."
        }
    }
}
