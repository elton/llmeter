import Foundation

public struct CodexTokens: Sendable, Equatable, Codable {
    public let accessToken: String
    public let refreshToken: String
    public let idToken: String
    public let accountId: String?
    public let expiresAt: Date

    public init(accessToken: String, refreshToken: String, idToken: String,
                accountId: String?, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.accountId = accountId
        self.expiresAt = expiresAt
    }
}
