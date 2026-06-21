import Foundation
import OSLog

final class KeychainService: @unchecked Sendable {
    static let shared = KeychainService()
    private let serviceName = "com.claudecodepanel.app"
    private let logger = Logger(subsystem: "com.claudecodepanel.app", category: "Keychain")

    func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                logError("get(\(key))", status: status)
            }
            return nil
        }
        guard let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    func set(_ key: String, value: String) {
        guard let valueData = value.data(using: .utf8) else {
            logger.error("Keychain set(\(key)): failed to encode value as UTF-8")
            return
        }

        // Try add first; if the item already exists, update instead (avoids TOCTOU)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: valueData,
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess { return }

        if addStatus == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: key,
            ]
            let attributes: [String: Any] = [
                kSecValueData as String: valueData
            ]
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            if updateStatus != errSecSuccess {
                logError("update(\(key))", status: updateStatus)
            }
        } else {
            logError("add(\(key))", status: addStatus)
        }
    }

    func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logError("delete(\(key))", status: status)
        }
    }

    // MARK: - Error logging

    private func logError(_ operation: String, status: OSStatus) {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown error"
        logger.error("Keychain \(operation) failed: \(message) (code: \(status))")
    }
}
