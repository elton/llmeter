import Foundation
import Security

public protocol AppKeychain: Sendable {
    func set(_ data: Data, for key: String)
    func get(_ key: String) -> Data?
    func delete(_ key: String)
}

public final class InMemoryKeychain: AppKeychain, @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: Data] = [:]
    public init() {}
    public func set(_ data: Data, for key: String) { lock.lock(); store[key] = data; lock.unlock() }
    public func get(_ key: String) -> Data? { lock.lock(); defer { lock.unlock() }; return store[key] }
    public func delete(_ key: String) { lock.lock(); store[key] = nil; lock.unlock() }
}

public final class SecAppKeychain: AppKeychain, @unchecked Sendable {
    private let service: String
    public init(service: String = "com.elton.llmeter") { self.service = service }

    private func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }

    public func set(_ data: Data, for key: String) {
        SecItemDelete(query(key) as CFDictionary)
        var attrs = query(key)
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attrs as CFDictionary, nil)
    }

    public func get(_ key: String) -> Data? {
        var q = query(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    public func delete(_ key: String) { SecItemDelete(query(key) as CFDictionary) }
}
