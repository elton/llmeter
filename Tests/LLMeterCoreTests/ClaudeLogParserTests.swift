import Testing
import Foundation
@testable import LLMeterCore

struct ClaudeLogParserTests {
    @Test func parsesUsageEntriesAndSkipsNonUsageLines() throws {
        let entries = ClaudeLogParser.entries(fromJSONL: loadFixture("claude-session.jsonl"))
        #expect(entries.count == 2)

        let first = entries[0]
        #expect(first.model == "claude-sonnet-4-6")
        #expect(first.inputTokens == 10)
        #expect(first.outputTokens == 20)
        #expect(first.cacheReadTokens == 100)
        #expect(first.cacheCreationTokens == 5)
        #expect(first.totalTokens == 135)
        #expect(first.timestamp == ISO8601DateFormatter().date(from: "2026-06-22T03:00:01Z"))

        #expect(entries[1].model == "claude-opus-4-8")
    }

    @Test func ignoresMalformedLines() {
        let jsonl = "not json\n{\"type\":\"assistant\"}\n"
        #expect(ClaudeLogParser.entries(fromJSONL: jsonl).isEmpty)
    }
}
