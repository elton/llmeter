import Testing
import Foundation
@testable import LLMeterCore

struct CodexOAuthTests {
    @Test func authorizeURLHasAllRequiredParams() {
        let url = CodexOAuth.authorizeURL(redirectURI: "http://localhost:1455/auth/callback",
                                          codeChallenge: "CHALLENGE", state: "STATE")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        let dict = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        #expect(url.absoluteString.hasPrefix("https://auth.openai.com/oauth/authorize?"))
        #expect(dict["response_type"] == "code")
        #expect(dict["client_id"] == "app_EMoamEEZ73f0CkXaXp7hrann")
        #expect(dict["redirect_uri"] == "http://localhost:1455/auth/callback")
        #expect(dict["scope"] == "openid profile email offline_access api.connectors.read api.connectors.invoke")
        #expect(dict["code_challenge"] == "CHALLENGE")
        #expect(dict["code_challenge_method"] == "S256")
        #expect(dict["state"] == "STATE")
        #expect(dict["id_token_add_organizations"] == "true")
        #expect(dict["codex_cli_simplified_flow"] == "true")
        #expect(dict["originator"] == "codex_cli_rs")
    }

    @Test func tokenExchangeBodyIsFormEncoded() {
        let body = CodexOAuth.tokenExchangeBody(code: "CODE", redirectURI: "http://localhost:1455/auth/callback",
                                                codeVerifier: "VERIFIER")
        let dict = formDict(body)
        #expect(dict["grant_type"] == "authorization_code")
        #expect(dict["code"] == "CODE")
        #expect(dict["redirect_uri"] == "http://localhost:1455/auth/callback")
        #expect(dict["client_id"] == "app_EMoamEEZ73f0CkXaXp7hrann")
        #expect(dict["code_verifier"] == "VERIFIER")
    }

    @Test func refreshBodyIsFormEncoded() {
        let dict = formDict(CodexOAuth.refreshBody(refreshToken: "RT"))
        #expect(dict["grant_type"] == "refresh_token")
        #expect(dict["refresh_token"] == "RT")
        #expect(dict["client_id"] == "app_EMoamEEZ73f0CkXaXp7hrann")
    }

    @Test func parseTokenResponseExtractsTokensAndAccountId() throws {
        let now = Date(timeIntervalSince1970: 1_782_000_000)
        let data = Data(loadFixture("codex-token-response.json").utf8)
        let tokens = try CodexOAuth.parseTokenResponse(data, now: now)
        #expect(tokens.accessToken == "fake-access-token")
        #expect(tokens.refreshToken == "rt.fake-refresh")
        #expect(tokens.accountId == "user-FAKE0000")
        #expect(tokens.expiresAt == now.addingTimeInterval(864000))
    }

    @Test func parseTokenResponseToleratesOmittedRefreshAndIdToken() throws {
        // A non-rotating refresh may return only a new access token + expiry.
        let now = Date(timeIntervalSince1970: 1_782_000_000)
        let json = #"{"access_token":"new-access","expires_in":3600,"token_type":"Bearer"}"#
        let tokens = try CodexOAuth.parseTokenResponse(Data(json.utf8), now: now)
        #expect(tokens.accessToken == "new-access")
        #expect(tokens.refreshToken == "")
        #expect(tokens.idToken == "")
        #expect(tokens.accountId == nil)
        #expect(tokens.expiresAt == now.addingTimeInterval(3600))
    }

    @Test func loginGrantRequiresRefreshAndAccount() {
        // The initial authorization-code login must carry refresh_token + account id.
        let json = #"{"access_token":"a","expires_in":3600,"token_type":"Bearer"}"#
        #expect(throws: CodexOAuthError.decode) {
            try CodexOAuth.parseTokenResponse(Data(json.utf8), now: Date(), requireCompleteGrant: true)
        }
    }

    private func formDict(_ body: String) -> [String: String] {
        var out: [String: String] = [:]
        for pair in body.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2 {
                out[String(kv[0])] = String(kv[1]).removingPercentEncoding ?? String(kv[1])
            }
        }
        return out
    }
}
