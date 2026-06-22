import Foundation
import Testing
@testable import LLMeterCore

struct StubClock: Clock {
    let fixed: Date
    init(now: Date) { self.fixed = now }
    var now: Date { fixed }
}

struct StubHTTPClient: HTTPClient {
    enum StubError: Error { case forced }
    let result: Result<(Data, Int), Error>

    func get(_ request: HTTPRequest) async throws -> (Data, HTTPURLResponse) {
        switch result {
        case .success(let (data, code)):
            let resp = HTTPURLResponse(url: request.url, statusCode: code,
                                       httpVersion: nil, headerFields: nil)!
            return (data, resp)
        case .failure(let error):
            throw error
        }
    }
}

/// Loads a file from the test bundle's copied `Fixtures` directory as a String.
func loadFixture(_ name: String) -> String {
    guard let url = Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: nil)
            ?? Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")
    else {
        Issue.record("fixture not found: \(name)")
        return ""
    }
    return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
}

struct StubProvider: QuotaProvider {
    let id: ProviderID
    let result: Result<UsageSnapshot, ProviderError>
    func fetch() async -> Result<UsageSnapshot, ProviderError> { result }
}
