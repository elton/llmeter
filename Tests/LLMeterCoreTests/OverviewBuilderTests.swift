import Testing
import Foundation
@testable import LLMeterCore

struct OverviewBuilderTests {
    private let now = Date(timeIntervalSince1970: 1_782_000_000)

    @Test func oneCardPerProviderInOrder() {
        let codex = UsageSnapshot(provider: .codex, windows: [
            UsageWindow(kind: .fiveHour, label: "5h", percent: 77, resetsAt: now.addingTimeInterval(41 * 60)),
            UsageWindow(kind: .weekly, label: "Weekly", percent: 12),
        ], capturedAt: now, sourceLabel: "live")
        let claude = UsageSnapshot(provider: .claude, windows: [
            UsageWindow(kind: .rolling, label: "7d", percent: nil, usedTokens: 345_809_311, estimatedCostUSD: 20457.46),
        ], capturedAt: now, sourceLabel: "local logs")

        let cards = OverviewBuilder.cards(from: [.codex: codex, .claude: claude], now: now)
        #expect(cards.map(\.id) == ["overview-codex", "overview-claude"])

        let c = cards[0]
        #expect(c.title == "CODEX")
        #expect(c.kind == .gauge)
        #expect(c.value == "23% left")      // worst window (77% used → 23% remaining)
        #expect(c.severity == .warning)

        let cl = cards[1]
        #expect(cl.title == "CLAUDE")
        #expect(cl.kind == .usage)
        #expect(cl.value == "346M tokens")     // 7d usage
    }

    @Test func unavailableProviderShownPlain() {
        let cards = OverviewBuilder.cards(from: [.codex: nil, .claude: nil], now: now)
        #expect(cards.allSatisfy { $0.kind == .plain && $0.value == "—" })
    }

    @Test func claudePicksWidestUsageWindowRegardlessOfOrder() {
        // Real Claude emits 5h, 7d, Today in that order — the overview must pick 7d (widest).
        let claude = UsageSnapshot(provider: .claude, windows: [
            UsageWindow(kind: .rolling, label: "5h", percent: nil, usedTokens: 26_000_000, estimatedCostUSD: 1),
            UsageWindow(kind: .rolling, label: "7d", percent: nil, usedTokens: 345_000_000, estimatedCostUSD: 20),
            UsageWindow(kind: .rolling, label: "Today", percent: nil, usedTokens: 35_000_000, estimatedCostUSD: 2),
        ], capturedAt: now, sourceLabel: "local logs")

        let cards = OverviewBuilder.cards(from: [.claude: claude], now: now)
        let claudeCard = cards.first { $0.id == "overview-claude" }!
        #expect(claudeCard.value == "345M tokens")   // 7d (345M), not Today (35M) or 5h (26M)
    }

    @Test func claudeBreaksTokenTiesByCostPickingWidest() {
        // usedTokens excludes cache reads, so 5h/7d/Today can tie on tokens; the 7d
        // window (highest cost) must still win.
        let claude = UsageSnapshot(provider: .claude, windows: [
            UsageWindow(kind: .rolling, label: "5h", percent: nil, usedTokens: 100_000_000, estimatedCostUSD: 5),
            UsageWindow(kind: .rolling, label: "7d", percent: nil, usedTokens: 100_000_000, estimatedCostUSD: 50),
            UsageWindow(kind: .rolling, label: "Today", percent: nil, usedTokens: 100_000_000, estimatedCostUSD: 10),
        ], capturedAt: now, sourceLabel: "local logs")

        let cards = OverviewBuilder.cards(from: [.claude: claude], now: now)
        let claudeCard = cards.first { $0.id == "overview-claude" }!
        #expect(claudeCard.subtitle == "~$50.00")   // 7d (highest cost) wins the token tie
    }
}
