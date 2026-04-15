import Foundation
import Security

/// Secure storage for sensitive credentials using the iOS Keychain.
/// Replaces UserDefaults for API keys.
enum KeychainService {

    private static let service = Bundle.main.bundleIdentifier ?? "com.paula.app"

    enum Key: String {
        case claudeAPIKey  = "claudeAPIKey"
        case whisperAPIKey = "whisperAPIKey"
        case geminiAPIKey  = "geminiAPIKey"
        case groqAPIKey    = "groqAPIKey"
    }

    // MARK: - Write

    @discardableResult
    static func set(_ value: String, for key: Key) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key.rawValue
        ]
        // Delete existing entry first
        SecItemDelete(query as CFDictionary)

        if value.isEmpty { return true }   // empty = just delete

        var addQuery = query
        addQuery[kSecValueData] = data
        addQuery[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    // MARK: - Read

    static func get(_ key: Key) -> String {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key.rawValue,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess,
           let data = result as? Data,
           let string = String(data: data, encoding: .utf8),
           !string.isEmpty {
            return string
        }

        // Fall back to UserDefaults (used when Keychain is unavailable, e.g. Simulator)
        return UserDefaults.standard.string(forKey: key.rawValue) ?? ""
    }

    // MARK: - Delete

    @discardableResult
    static func delete(_ key: Key) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
