import Testing
import Foundation
@testable import LLMeterCore

struct CodexProviderTests {
    private func tempAuthFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: "auth.json")
        try loadFixture("codex-auth.json").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func tempSessionsDirWithRollout() throws -> URL {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let day = base.appending(path: "2026/06/22")
        try FileManager.default.createDirectory(at: day, withIntermediateDirectories: true)
        try loadFixture("codex-rollout.jsonl")
            .write(to: day.appending(path: "rollout-test.jsonl"), atomically: true, encoding: .utf8)
        return base
    }

    @Test func usesLiveAPIWhenAvailable() async throws {
        let auth = try tempAuthFile()
        let data = Data(loadFixture("codex-wham-usage.json").utf8)
        let provider = CodexProvider(
            http: StubHTTPClient(result: .success((data, 200))),
            clock: StubClock(now: Date(timeIntervalSince1970: 1_782_104_558)),
            authPath: auth,
            sessionsDir: FileManager.default.temporaryDirectory.appending(path: "missing-\(UUID().uuidString)")
        )
        let snap = try #require(try? (await provider.fetch()).get())
        #expect(snap.sourceLabel == "live")
        #expect(snap.windows.first { $0.kind == .fiveHour }?.percent == 77)
    }

    @Test func fallsBackToRolloutWhenAPIFails() async throws {
        let auth = try tempAuthFile()
        let sessions = try tempSessionsDirWithRollout()
        let provider = CodexProvider(
            http: StubHTTPClient(result: .failure(StubHTTPClient.StubError.forced)),
            clock: StubClock(now: Date(timeIntervalSince1970: 1_782_104_558)),
            authPath: auth,
            sessionsDir: sessions
        )
        let snap = try #require(try? (await provider.fetch()).get())
        #expect(snap.isStale)
        #expect(snap.windows.first { $0.kind == .fiveHour }?.percent == 50)  // from rollout
    }

    @Test func fallsBackWhenLiveReturnsEmptyUsage() async throws {
        // Live API answers 200 but with no usable rate_limit (schema drift) →
        // must fall back to the cached rollout, not surface an empty live snapshot.
        let auth = try tempAuthFile()
        let sessions = try tempSessionsDirWithRollout()
        let emptyBody = Data(#"{"plan_type":"prolite"}"#.utf8)
        let provider = CodexProvider(
            http: StubHTTPClient(result: .success((emptyBody, 200))),
            clock: StubClock(now: Date(timeIntervalSince1970: 1_782_104_558)),
            authPath: auth,
            sessionsDir: sessions
        )
        let snap = try #require(try? (await provider.fetch()).get())
        #expect(snap.isStale)
        #expect(snap.sourceLabel == "local cache")
        #expect(snap.windows.first { $0.kind == .fiveHour }?.percent == 50)  // from rollout
    }

    @Test func failsWhenNoCredentialsAndNoRollout() async {
        let provider = CodexProvider(
            http: StubHTTPClient(result: .failure(StubHTTPClient.StubError.forced)),
            clock: StubClock(now: Date()),
            authPath: FileManager.default.temporaryDirectory.appending(path: "nope-\(UUID().uuidString).json"),
            sessionsDir: FileManager.default.temporaryDirectory.appending(path: "nope-dir-\(UUID().uuidString)")
        )
        let result = await provider.fetch()
        #expect(result == .failure(.noCredentials))
    }
}
