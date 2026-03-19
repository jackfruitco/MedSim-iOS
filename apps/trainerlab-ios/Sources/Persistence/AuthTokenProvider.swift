import Foundation
import Security
import SharedModels

public protocol AuthTokenProvider: Sendable {
    func loadTokens() -> AuthTokens?
    func saveTokens(_ tokens: AuthTokens)
    func clearTokens()
}

public final class KeychainTokenStore: AuthTokenProvider, @unchecked Sendable {
    private let service: String
    private let account: String

    public init(service: String = "com.jackfruitco.trainerlab.auth", account: String = "jwt.tokens") {
        self.service = service
        self.account = account
    }

    public func loadTokens() -> AuthTokens? {
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
        return try? JSONDecoder().decode(AuthTokens.self, from: data)
    }

    public func saveTokens(_ tokens: AuthTokens) {
        guard let data = try? JSONEncoder().encode(tokens) else {
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    public func clearTokens() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
