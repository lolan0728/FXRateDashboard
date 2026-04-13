import Foundation
import Security

public protocol TokenStoreProtocol: Sendable {
    func loadToken() -> String?
    func saveToken(_ token: String) throws
    func deleteToken() throws
    func hasToken() -> Bool
}

public enum KeychainTokenStoreError: LocalizedError {
    case unexpectedStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case let .unexpectedStatus(status):
            "Keychain operation failed with status \(status)."
        }
    }
}

public final class KeychainTokenStore: TokenStoreProtocol, @unchecked Sendable {
    private let service: String
    private let account: String

    public init(service: String = "FXRateDashboard", account: String = "wise-api-token") {
        self.service = service
        self.account = account
    }

    public func loadToken() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status != errSecItemNotFound else {
            return nil
        }

        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    public func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
        let query = baseQuery()
        let attributes = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus != errSecItemNotFound {
            throw KeychainTokenStoreError.unexpectedStatus(updateStatus)
        }

        var createQuery = query
        createQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(createQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainTokenStoreError.unexpectedStatus(addStatus)
        }
    }

    public func deleteToken() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainTokenStoreError.unexpectedStatus(status)
        }
    }

    public func hasToken() -> Bool {
        loadToken()?.isEmpty == false
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
