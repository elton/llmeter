import Foundation

public enum ProviderError: Error, Sendable, Equatable {
    case noCredentials
    case network(String)
    case decode(String)
    case unavailable
}

public protocol QuotaProvider: Sendable {
    var id: ProviderID { get }
    func fetch() async -> Result<UsageSnapshot, ProviderError>
}
