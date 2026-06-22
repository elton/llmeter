import Foundation

public enum CredentialError: Error, Equatable {
    case missing
}

public struct CodexCredentials: Sendable, Equatable {
    public let accessToken: String
    public let accountId: String
}

public enum CodexCredentialsReader {
    private struct AuthFile: Decodable {
        let tokens: Tokens?
        struct Tokens: Decodable {
            let access_token: String?
            let account_id: String?
        }
    }

    public static var defaultPath: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex/auth.json")
    }

    /// Read-only. Never mutates the file. Never logs the token.
    public static func read(authJSONPath: URL) throws -> CodexCredentials {
        let data = try Data(contentsOf: authJSONPath)
        let auth = try JSONDecoder().decode(AuthFile.self, from: data)
        guard let token = auth.tokens?.access_token, !token.isEmpty,
              let accountId = auth.tokens?.account_id, !accountId.isEmpty else {
            throw CredentialError.missing
        }
        return CodexCredentials(accessToken: token, accountId: accountId)
    }
}
