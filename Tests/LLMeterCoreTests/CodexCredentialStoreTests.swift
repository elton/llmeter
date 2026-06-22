import Testing
import Foundation
@testable import LLMeterCore

struct CodexCredentialStoreTests {
    @Test func savesAndLoadsTokens() {
        let store = CodexCredentialStore(keychain: InMemoryKeychain())
        #expect(store.load() == nil)

        let tokens = CodexTokens(accessToken: "a", refreshToken: "r", idToken: "i",
                                 accountId: "user-1", expiresAt: Date(timeIntervalSince1970: 1_782_000_000))
        store.save(tokens)
        #expect(store.load() == tokens)

        store.clear()
        #expect(store.load() == nil)
    }
}
