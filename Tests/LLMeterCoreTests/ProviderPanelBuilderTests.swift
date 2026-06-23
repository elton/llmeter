import Testing
import Foundation
@testable import LLMeterCore

struct ProviderPanelBuilderTests {
    private let now = Date(timeIntervalSince1970: 1_782_000_000)

    @Test func codexProducesGaugeCardsPlusPlanAndCredits() {
        let snap = UsageSnapshot(provider: .codex, planType: "prolite", windows: [
            UsageWindow(kind: .fiveHour, label: "5h", percent: 77, resetsAt: now.addingTimeInterval(41 * 60)),
            UsageWindow(kind: .weekly, label: "Weekly", percent: 12, resetsAt: now.addingTimeInterval(6 * 86400)),
            UsageWindow(kind: .model, label: "GPT-5.3-Codex-Spark", percent: 0, resetsAt: nil),
        ], creditsBalance: "0", capturedAt: now, sourceLabel: "live")

        let cards = ProviderPanelBuilder.cards(for: snap, now: now)

        let five = cards.first { $0.id == "codex-fiveHour" }!
        #expect(five.kind == .gauge)
        #expect(five.title == "5-HOUR")
        #expect(five.percent == 77)             // ring still shows used %
        #expect(five.value == "23% left")       // value line shows what's remaining
        #expect(five.subtitle == "resets in 41m")
        #expect(five.severity == .warning)

        #expect(cards.contains { $0.id == "codex-weekly" && $0.title == "WEEKLY" })
        #expect(cards.contains { $0.kind == .gauge && $0.title == "GPT-5.3-CODEX-SPARK" })
        #expect(cards.contains { $0.id == "codex-plan" && $0.kind == .plain && $0.value == "Pro Lite" })
        #expect(cards.contains { $0.id == "codex-credits" && $0.kind == .plain })
    }

    @Test func claudeProducesUsageCardsWithCost() {
        let snap = UsageSnapshot(provider: .claude, windows: [
            UsageWindow(kind: .rolling, label: "5h", percent: nil, usedTokens: 25_926_963, estimatedCostUSD: 1375.13),
            UsageWindow(kind: .rolling, label: "7d", percent: nil, usedTokens: 345_809_311, estimatedCostUSD: 20457.46),
        ], capturedAt: now, sourceLabel: "local logs")

        let cards = ProviderPanelBuilder.cards(for: snap, now: now)

        let five = cards.first!
        #expect(five.kind == .usage)
        #expect(five.title == "5H")
        #expect(five.percent == nil)
        #expect(five.value == "26M tok")
        #expect(five.subtitle == "~$1375.13")
        #expect(five.severity == .unknown)
        #expect(cards.contains { $0.title == "7D" && $0.value == "346M tok" })
    }
}
