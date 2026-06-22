import Foundation

public enum CodexOAuthError: Error, Equatable { case decode }

public enum CodexOAuth {
    public static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    public static let issuer = "https://auth.openai.com"
    public static let scope = "openid profile email offline_access api.connectors.read api.connectors.invoke"
    public static let defaultPort = 1455
    public static let fallbackPort = 1457

    public static func redirectURI(port: Int) -> String { "http://localhost:\(port)/auth/callback" }

    public static func authorizeURL(redirectURI: String, codeChallenge: String, state: String) -> URL {
        var c = URLComponents(string: "\(issuer)/oauth/authorize")!
        c.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "scope", value: scope),
            .init(name: "code_challenge", value: codeChallenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            .init(name: "id_token_add_organizations", value: "true"),
            .init(name: "codex_cli_simplified_flow", value: "true"),
            .init(name: "originator", value: "codex_cli_rs"),
        ]
        return c.url!
    }

    public static func tokenExchangeBody(code: String, redirectURI: String, codeVerifier: String) -> String {
        form([
            ("grant_type", "authorization_code"), ("code", code),
            ("redirect_uri", redirectURI), ("client_id", clientID), ("code_verifier", codeVerifier),
        ])
    }

    public static func refreshBody(refreshToken: String) -> String {
        form([("grant_type", "refresh_token"), ("refresh_token", refreshToken), ("client_id", clientID)])
    }

    /// Parses a token endpoint response. Pass `requireCompleteGrant: true` for the
    /// initial authorization-code login (must carry a refresh token + account id);
    /// the lenient default suits the refresh grant, which may omit unchanged fields.
    public static func parseTokenResponse(_ data: Data, now: Date, requireCompleteGrant: Bool = false) throws -> CodexTokens {
        struct Response: Decodable {
            let access_token: String
            let refresh_token: String?   // may be omitted when not rotated
            let id_token: String?        // may be omitted on refresh
            let expires_in: Double
        }
        guard let r = try? JSONDecoder().decode(Response.self, from: data) else { throw CodexOAuthError.decode }
        let idToken = r.id_token ?? ""
        let tokens = CodexTokens(
            accessToken: r.access_token,
            refreshToken: r.refresh_token ?? "",
            idToken: idToken,
            accountId: accountId(fromIDToken: idToken),
            expiresAt: now.addingTimeInterval(r.expires_in)
        )
        if requireCompleteGrant {
            guard !tokens.refreshToken.isEmpty, tokens.accountId != nil else { throw CodexOAuthError.decode }
        }
        return tokens
    }

    /// Extracts chatgpt_account_id from the id_token's `https://api.openai.com/auth` claim.
    public static func accountId(fromIDToken idToken: String) -> String? {
        let parts = idToken.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var b64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let auth = obj["https://api.openai.com/auth"] as? [String: Any] else { return nil }
        return auth["chatgpt_account_id"] as? String
    }

    private static func form(_ pairs: [(String, String)]) -> String {
        var cs = CharacterSet.urlQueryAllowed
        cs.remove(charactersIn: "+&=")
        return pairs.map { "\($0.0)=\($0.1.addingPercentEncoding(withAllowedCharacters: cs) ?? $0.1)" }
            .joined(separator: "&")
    }
}
