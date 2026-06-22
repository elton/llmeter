import Testing
import Foundation
@testable import LLMeterCore

struct CodexRolloutParserTests {
    @Test func picksLastRateLimitsAndMarksStale() throws {
        let captured = Date(timeIntervalSince1970: 1_782_104_558)
        let snap = try #require(
            CodexRolloutParser.snapshot(fromJSONL: loadFixture("codex-rollout.jsonl"), capturedAt: captured)
        )
        #expect(snap.isStale)
        #expect(snap.sourceLabel == "local cache")

        let five = try #require(snap.windows.first { $0.kind == .fiveHour })
        #expect(five.percent == 50.0)   // from the LAST line, not the first
        #expect(five.resetsAt == Date(timeIntervalSince1970: 1782107036))

        let week = try #require(snap.windows.first { $0.kind == .weekly })
        #expect(week.percent == 8.0)
    }

    @Test func returnsNilWhenNoRateLimitsPresent() {
        let jsonl = "{\"type\":\"event_msg\",\"payload\":{\"message\":\"hi\"}}\n"
        #expect(CodexRolloutParser.snapshot(fromJSONL: jsonl, capturedAt: Date()) == nil)
    }

    @Test func parsesTopLevelRateLimits() throws {
        // Some events carry rate_limits at the top level rather than under `payload`.
        let jsonl = "{\"type\":\"token_count\",\"rate_limits\":{\"primary\":{\"used_percent\":42.0,\"resets_at\":1782107036},\"secondary\":{\"used_percent\":7.0,\"resets_at\":1782693836}}}\n"
        let snap = try #require(CodexRolloutParser.snapshot(fromJSONL: jsonl, capturedAt: Date()))
        #expect(snap.windows.first { $0.kind == .fiveHour }?.percent == 42.0)
        #expect(snap.windows.first { $0.kind == .weekly }?.percent == 7.0)
    }
}
