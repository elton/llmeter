import Foundation

public struct CodexTokenProvider: Sendable {
    private let store: CodexCredentialStore
    private let http: HTTPClient
    private let clock: Clock

    public init(store: CodexCredentialStore, http: HTTPClient, clock: Clock) {
        self.store = store
        self.http = http
        self.clock = clock
    }

    /// Returns a valid (non-expired) access token + account id, refreshing via the
    /// refresh grant when the stored token is expired or within 60s of expiry.
    /// Returns nil when nothing is stored or a refresh fails.
    public func validCredentials() async -> CodexCredentials? {
        guard var tokens = store.load() else { return nil }
        if tokens.expiresAt <= clock.now.addingTimeInterval(60) {
            guard let refreshed = await refresh(tokens) else { return nil }
            // If the user signed out (store cleared) or another refresh rotated the
            // token during our network call, do NOT resurrect the old credentials.
            guard let current = store.load(), current.refreshToken == tokens.refreshToken else { return nil }
            store.save(refreshed)
            tokens = refreshed
        }
        guard let account = tokens.accountId else { return nil }
        return CodexCredentials(accessToken: tokens.accessToken, accountId: account)
    }

    private func refresh(_ old: CodexTokens) async -> CodexTokens? {
        let request = HTTPRequest(url: URL(string: "\(CodexOAuth.issuer)/oauth/token")!,
                                  headers: ["Content-Type": "application/x-www-form-urlencoded"])
        guard let (data, resp) = try? await http.post(request, body: CodexOAuth.refreshBody(refreshToken: old.refreshToken)),
              resp.statusCode == 200,
              let fresh = try? CodexOAuth.parseTokenResponse(data, now: clock.now) else { return nil }
        // Preserve prior values the refresh response may have omitted.
        return CodexTokens(
            accessToken: fresh.accessToken,
            refreshToken: fresh.refreshToken.isEmpty ? old.refreshToken : fresh.refreshToken,
            idToken: fresh.idToken.isEmpty ? old.idToken : fresh.idToken,
            accountId: fresh.accountId ?? old.accountId,
            expiresAt: fresh.expiresAt
        )
    }
}
