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
        try respond(request)
    }

    func post(_ request: HTTPRequest, body: String) async throws -> (Data, HTTPURLResponse) {
        try respond(request)
    }

    private func respond(_ request: HTTPRequest) throws -> (Data, HTTPURLResponse) {
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

/// Returns a different result on each `fetch()` call (last value repeats),
/// so tests can simulate "succeeds, then fails".
actor SequenceProvider: QuotaProvider {
    nonisolated let id: ProviderID
    private var results: [Result<UsageSnapshot, ProviderError>]

    init(id: ProviderID, results: [Result<UsageSnapshot, ProviderError>]) {
        self.id = id
        self.results = results
    }

    func fetch() async -> Result<UsageSnapshot, ProviderError> {
        if results.count > 1 { return results.removeFirst() }
        return results.first ?? .failure(.unavailable)
    }
}

/// Counts `fetch()` calls and delays each one, so tests can prove overlapping
/// refreshes are coalesced into a single provider sweep.
actor CountingProvider: QuotaProvider {
    nonisolated let id: ProviderID
    private let snapshot: UsageSnapshot
    private let delayNanos: UInt64
    private(set) var fetchCount = 0

    init(id: ProviderID, snapshot: UsageSnapshot, delaySeconds: Double) {
        self.id = id
        self.snapshot = snapshot
        self.delayNanos = UInt64(delaySeconds * 1_000_000_000)
    }

    func fetch() async -> Result<UsageSnapshot, ProviderError> {
        fetchCount += 1
        try? await Task.sleep(nanoseconds: delayNanos)
        return .success(snapshot)
    }
}

/// Succeeds on the first fetch, then hangs (cancellable) on later calls,
/// reporting failure if cancelled — mimics a real cancelled URLSession request.
actor SucceedThenHangProvider: QuotaProvider {
    nonisolated let id: ProviderID
    private let snapshot: UsageSnapshot
    private var calls = 0

    init(id: ProviderID, snapshot: UsageSnapshot) {
        self.id = id
        self.snapshot = snapshot
    }

    func fetch() async -> Result<UsageSnapshot, ProviderError> {
        calls += 1
        if calls == 1 { return .success(snapshot) }
        do {
            try await Task.sleep(nanoseconds: 5_000_000_000)
        } catch {
            return .failure(.network("cancelled"))
        }
        return .success(snapshot)
    }
}
