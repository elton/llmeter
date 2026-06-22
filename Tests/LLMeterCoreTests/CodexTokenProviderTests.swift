import Testing
import Foundation
@testable import LLMeterCore

@MainActor
struct CodexTokenProviderTests {
    private let now = Date(timeIntervalSince1970: 1_782_000_000)

    private func tokens(expiresAt: Date) -> CodexTokens {
        CodexTokens(accessToken: "old-access", refreshToken: "rt.old", idToken: "i",
                    accountId: "acct-1", expiresAt: expiresAt)
    }

    @Test func returnsStoredTokenWhenFresh() async {
        let store = CodexCredentialStore(keychain: InMemoryKeychain())
        store.save(tokens(expiresAt: now.addingTimeInterval(86400)))
        // http must NOT be called when the token is fresh.
        let http = StubHTTPClient(result: .failure(StubHTTPClient.StubError.forced))
        let tp = CodexTokenProvider(store: store, http: http, clock: StubClock(now: now))

        let creds = await tp.validCredentials()
        #expect(creds?.accessToken == "old-access")
        #expect(creds?.accountId == "acct-1")
    }

    @Test func refreshesWhenExpiredAndPreservesAccountId() async {
        let store = CodexCredentialStore(keychain: InMemoryKeychain())
        store.save(tokens(expiresAt: now.addingTimeInterval(-10)))   // expired
        let data = Data(loadFixture("codex-refresh-response.json").utf8)
        let http = StubHTTPClient(result: .success((data, 200)))
        let tp = CodexTokenProvider(store: store, http: http, clock: StubClock(now: now))

        let creds = await tp.validCredentials()
        #expect(creds?.accessToken == "refreshed-access")          // refreshed
        #expect(creds?.accountId == "acct-1")                       // preserved (refresh omitted id_token)
        #expect(store.load()?.accessToken == "refreshed-access")    // persisted
        #expect(store.load()?.refreshToken == "rt.refreshed")
    }

    @Test func nilWhenNothingStored() async {
        let tp = CodexTokenProvider(store: CodexCredentialStore(keychain: InMemoryKeychain()),
                                    http: StubHTTPClient(result: .failure(StubHTTPClient.StubError.forced)),
                                    clock: StubClock(now: now))
        #expect(await tp.validCredentials() == nil)
    }
}
