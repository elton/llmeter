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
