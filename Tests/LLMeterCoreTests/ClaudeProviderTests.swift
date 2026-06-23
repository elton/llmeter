import Testing
import Foundation
@testable import LLMeterCore

struct ClaudeProviderTests {
    private func tempProjectsDir() throws -> URL {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let proj = base.appending(path: "proj-a")
        try FileManager.default.createDirectory(at: proj, withIntermediateDirectories: true)
        // One entry 2h ago (inside 5h), one entry 3 days ago (inside 7d, outside 5h).
        let jsonl = """
        {"type":"assistant","timestamp":"2026-06-22T01:00:00.000Z","message":{"model":"claude-sonnet-4-6","usage":{"input_tokens":100,"output_tokens":200,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
        {"type":"assistant","timestamp":"2026-06-19T00:00:00.000Z","message":{"model":"claude-sonnet-4-6","usage":{"input_tokens":1000,"output_tokens":2000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
        """
        try jsonl.write(to: proj.appending(path: "session.jsonl"), atomically: true, encoding: .utf8)
        return base
    }

    @Test func aggregatesFiveHourSevenDayTodayWindows() async throws {
        // now = 2026-06-22T03:00:00Z → 5h window starts 2026-06-21T22:00Z
        let now = ISO8601DateFormatter().date(from: "2026-06-22T03:00:00Z")!
        let provider = ClaudeProvider(clock: StubClock(now: now), projectsDir: try tempProjectsDir())

        let snap = try #require(try? (await provider.fetch()).get())
        #expect(snap.provider == .claude)
        #expect(snap.sourceLabel == "local logs")

        let five = try #require(snap.windows.first { $0.label == "5h" })
        #expect(five.percent == nil)                 // usage-only, no quota %
        #expect(five.resetsAt == nil)
        #expect(five.usedTokens == 300)              // only the 2h-ago entry

        let seven = try #require(snap.windows.first { $0.label == "7d" })
        #expect(seven.usedTokens == 3300)            // both entries
    }

    @Test func skipsLogFilesModifiedBeforeWidestWindow() async throws {
        // A file last modified far before the 7-day window must be skipped without
        // being read — even if it contains an entry whose timestamp falls in-window.
        // (Real logs are append-only, so mtime >= newest entry; this guards the perf
        // short-circuit that stops us re-reading gigabytes of history every refresh.)
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let proj = base.appending(path: "p")
        try FileManager.default.createDirectory(at: proj, withIntermediateDirectories: true)

        let now = ISO8601DateFormatter().date(from: "2026-06-22T03:00:00Z")!

        // Fresh file (recent mtime), entry 1h ago → counted.
        let fresh = proj.appending(path: "fresh.jsonl")
        try "{\"type\":\"assistant\",\"timestamp\":\"2026-06-22T02:00:00.000Z\",\"message\":{\"model\":\"claude-sonnet-4-6\",\"usage\":{\"input_tokens\":10,\"output_tokens\":20,\"cache_read_input_tokens\":0,\"cache_creation_input_tokens\":0}}}\n"
            .write(to: fresh, atomically: true, encoding: .utf8)

        // Stale file: mtime 30 days before `now`, yet contains an in-window entry.
        // Must be skipped → its (huge) tokens excluded.
        let stale = proj.appending(path: "stale.jsonl")
        try "{\"type\":\"assistant\",\"timestamp\":\"2026-06-22T02:30:00.000Z\",\"message\":{\"model\":\"claude-sonnet-4-6\",\"usage\":{\"input_tokens\":9999,\"output_tokens\":9999,\"cache_read_input_tokens\":0,\"cache_creation_input_tokens\":0}}}\n"
            .write(to: stale, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-30 * 86400)],
                                              ofItemAtPath: stale.path)

        let provider = ClaudeProvider(clock: StubClock(now: now), projectsDir: base)
        let snap = try #require(try? (await provider.fetch()).get())
        let five = try #require(snap.windows.first { $0.label == "5h" })
        #expect(five.usedTokens == 30)   // only fresh.jsonl (10+20); stale skipped despite in-window timestamp
    }

    /// Writes `jsonl` to `url` and forces its modification date to `mtime`
    /// (atomic writes otherwise stamp the current wall-clock time).
    private func write(_ jsonl: String, to url: URL, mtime: Date) throws {
        try jsonl.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: mtime], ofItemAtPath: url.path)
    }

    private func entryLine(timestamp: String, input: Int, output: Int) -> String {
        "{\"type\":\"assistant\",\"timestamp\":\"\(timestamp)\",\"message\":{\"model\":\"claude-sonnet-4-6\",\"usage\":{\"input_tokens\":\(input),\"output_tokens\":\(output),\"cache_read_input_tokens\":0,\"cache_creation_input_tokens\":0}}}\n"
    }

    @Test func reusesCacheWhenFileModificationDateUnchanged() async throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let proj = base.appending(path: "p")
        try FileManager.default.createDirectory(at: proj, withIntermediateDirectories: true)
        let now = ISO8601DateFormatter().date(from: "2026-06-22T03:00:00Z")!
        let mtime = now.addingTimeInterval(-1800)   // 30 min ago, in-window
        let file = proj.appending(path: "s.jsonl")

        try write(entryLine(timestamp: "2026-06-22T02:30:00.000Z", input: 10, output: 20),
                  to: file, mtime: mtime)

        let cache = ClaudeLogCache()
        let provider = ClaudeProvider(clock: StubClock(now: now), projectsDir: base, cache: cache)
        let first = try #require(try? (await provider.fetch()).get())
        #expect(first.windows.first { $0.label == "5h" }?.usedTokens == 30)

        // Rewrite with very different content but RESTORE the same mtime: the cache
        // keys on (url, mtime), so it must return the stale parse — proving the file
        // was not re-read.
        try write(entryLine(timestamp: "2026-06-22T02:30:00.000Z", input: 9000, output: 9000),
                  to: file, mtime: mtime)
        let second = try #require(try? (await provider.fetch()).get())
        #expect(second.windows.first { $0.label == "5h" }?.usedTokens == 30)
    }

    @Test func reparsesWhenFileModificationDateChanges() async throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let proj = base.appending(path: "p")
        try FileManager.default.createDirectory(at: proj, withIntermediateDirectories: true)
        let now = ISO8601DateFormatter().date(from: "2026-06-22T03:00:00Z")!
        let file = proj.appending(path: "s.jsonl")

        try write(entryLine(timestamp: "2026-06-22T02:30:00.000Z", input: 10, output: 20),
                  to: file, mtime: now.addingTimeInterval(-1800))

        let cache = ClaudeLogCache()
        let provider = ClaudeProvider(clock: StubClock(now: now), projectsDir: base, cache: cache)
        _ = try #require(try? (await provider.fetch()).get())

        // New content AND a newer mtime → cache invalidated, fresh parse.
        try write(entryLine(timestamp: "2026-06-22T02:45:00.000Z", input: 100, output: 200),
                  to: file, mtime: now.addingTimeInterval(-900))
        let second = try #require(try? (await provider.fetch()).get())
        #expect(second.windows.first { $0.label == "5h" }?.usedTokens == 300)
    }

    @Test func usedTokensExcludeCacheReadsButCostCountsThem() async throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let proj = base.appending(path: "p")
        try FileManager.default.createDirectory(at: proj, withIntermediateDirectories: true)
        // 1h ago: 10 input + 20 output + 30 cache-creation + 5000 cache-READ.
        let jsonl = "{\"type\":\"assistant\",\"timestamp\":\"2026-06-22T02:00:00.000Z\",\"message\":{\"model\":\"claude-sonnet-4-6\",\"usage\":{\"input_tokens\":10,\"output_tokens\":20,\"cache_read_input_tokens\":5000,\"cache_creation_input_tokens\":30}}}\n"
        try jsonl.write(to: proj.appending(path: "s.jsonl"), atomically: true, encoding: .utf8)

        let now = ISO8601DateFormatter().date(from: "2026-06-22T03:00:00Z")!
        let provider = ClaudeProvider(clock: StubClock(now: now), projectsDir: base)
        let snap = try #require(try? (await provider.fetch()).get())

        let five = try #require(snap.windows.first { $0.label == "5h" })
        #expect(five.usedTokens == 60)                    // 10+20+30, the 5000 cache reads excluded
        #expect((five.estimatedCostUSD ?? 0) > 0)         // cost still prices cache reads (discounted)
    }
}
