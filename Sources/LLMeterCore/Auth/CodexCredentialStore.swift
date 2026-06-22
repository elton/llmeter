import Foundation

public struct CodexCredentialStore: Sendable {
    private let keychain: AppKeychain
    private let key = "codex.oauth.tokens"

    public init(keychain: AppKeychain) { self.keychain = keychain }

    public func save(_ tokens: CodexTokens) {
        if let data = try? JSONEncoder().encode(tokens) { keychain.set(data, for: key) }
    }

    public func load() -> CodexTokens? {
        guard let data = keychain.get(key) else { return nil }
        return try? JSONDecoder().decode(CodexTokens.self, from: data)
    }

    public func clear() { keychain.delete(key) }
}
