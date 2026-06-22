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
        #expect(c.value == "77%")           // worst window
        #expect(c.severity == .warning)

        let cl = cards[1]
        #expect(cl.title == "CLAUDE")
        #expect(cl.kind == .usage)
        #expect(cl.value == "346M tok")     // 7d usage
    }

    @Test func unavailableProviderShownPlain() {
        let cards = OverviewBuilder.cards(from: [.codex: nil, .claude: nil], now: now)
        #expect(cards.allSatisfy { $0.kind == .plain && $0.value == "—" })
    }
}
