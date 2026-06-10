import Foundation
import Security

public enum KeychainError: Error { case status(OSStatus) }

/// Minimal Codable storage in the login keychain, keyed by (service, account).
public enum Keychain {
    public static func save<T: Encodable>(_ value: T, service: String, account: String) throws {
        let data = try JSONEncoder().encode(value)
        delete(service: service, account: account)   // upsert
        let q: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String:   data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(q as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }

    public static func load<T: Decodable>(_ type: T.Type, service: String, account: String) throws -> T? {
        let q: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var out: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &out)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = out as? Data else {
            throw KeychainError.status(status)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    public static func delete(service: String, account: String) {
        let q: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(q as CFDictionary)
    }
}
