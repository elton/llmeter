import Testing
import Foundation
@testable import LLMeterCore

struct CodexUsageMapperTests {
    @Test func mapsPrimaryAndSecondaryWindows() throws {
        let captured = Date(timeIntervalSince1970: 1_782_104_558)
        let data = Data(loadFixture("codex-wham-usage.json").utf8)
        let snap = try CodexUsageMapper.snapshot(from: data, capturedAt: captured, sourceLabel: "live")

        #expect(snap.provider == .codex)
        #expect(snap.planType == "prolite")
        #expect(snap.creditsBalance == "0")
        #expect(snap.isStale == false)

        let five = try #require(snap.windows.first { $0.kind == .fiveHour })
        #expect(five.percent == 77)
        #expect(five.resetsAt == Date(timeIntervalSince1970: 1782107036))

        let week = try #require(snap.windows.first { $0.kind == .weekly })
        #expect(week.percent == 12)

        let model = try #require(snap.windows.first { $0.kind == .model })
        #expect(model.label == "GPT-5.3-Codex-Spark")
        #expect(model.percent == 0)
    }

    @Test func throwsOnGarbage() {
        #expect(throws: (any Error).self) {
            try CodexUsageMapper.snapshot(from: Data("not json".utf8), capturedAt: Date(), sourceLabel: "live")
        }
    }
}
