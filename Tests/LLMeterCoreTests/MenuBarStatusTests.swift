import Testing
import Foundation
@testable import LLMeterCore

struct MenuBarStatusTests {
    private let now = Date(timeIntervalSince1970: 1_782_000_000)

    @Test func codexPercentDrivesOverallAndLabel() {
        let codex = UsageSnapshot(provider: .codex, windows: [
            UsageWindow(kind: .fiveHour, label: "5h", percent: 77),
            UsageWindow(kind: .weekly, label: "Weekly", percent: 12),
        ], capturedAt: now, sourceLabel: "live")
        let claude = UsageSnapshot(provider: .claude, windows: [
            UsageWindow(kind: .rolling, label: "5h", percent: nil, usedTokens: 345_809_311),
        ], capturedAt: now, sourceLabel: "local logs")

        let status = MenuBarStatusBuilder.build(from: [.codex: codex, .claude: claude])
        #expect(status.overall == .warning)                       // 77% → warning, Claude ignored
        let codexLabel = status.providers.first { $0.provider == .codex }!
        #expect(codexLabel.text == "77%")
        #expect(codexLabel.severity == .warning)
        let claudeLabel = status.providers.first { $0.provider == .claude }!
        #expect(claudeLabel.text == "346M")
        #expect(claudeLabel.severity == .unknown)                 // usage-only
    }

    @Test func missingProviderShowsDash() {
        let status = MenuBarStatusBuilder.build(from: [.codex: nil, .claude: nil])
        #expect(status.overall == .unknown)
        #expect(status.providers.allSatisfy { $0.text == "—" && $0.severity == .unknown })
    }

    @Test func compactFormatting() {
        #expect(MenuBarStatusBuilder.compact(500) == "500")
        #expect(MenuBarStatusBuilder.compact(1_500) == "2K")
        #expect(MenuBarStatusBuilder.compact(1_000_000) == "1M")
        #expect(MenuBarStatusBuilder.compact(345_809_311) == "346M")
        #expect(MenuBarStatusBuilder.compact(8_510_557_191) == "8.5B")
    }
}
