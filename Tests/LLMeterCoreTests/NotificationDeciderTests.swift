import Testing
import Foundation
@testable import LLMeterCore

struct NotificationDeciderTests {
    private let now = Date(timeIntervalSince1970: 1_782_000_000)

    private func codex(_ pct: Double) -> UsageSnapshot {
        UsageSnapshot(provider: .codex,
                      windows: [UsageWindow(kind: .fiveHour, label: "5h", percent: pct)],
                      capturedAt: now, sourceLabel: "live")
    }

    @Test func firesSeventyOnUpwardCross() {
        let alerts = NotificationDecider.alerts(previous: [.codex: codex(60)], current: [.codex: codex(75)])
        #expect(alerts.map(\.threshold) == [70])
        #expect(alerts.first?.provider == .codex)
        #expect(alerts.first?.percent == 75)
    }

    @Test func firesNinetyButNotSeventyWhenAlreadyAboveSeventy() {
        let alerts = NotificationDecider.alerts(previous: [.codex: codex(75)], current: [.codex: codex(95)])
        #expect(alerts.map(\.threshold) == [90])
    }

    @Test func noAlertWhenStaysAboveThreshold() {
        let alerts = NotificationDecider.alerts(previous: [.codex: codex(95)], current: [.codex: codex(96)])
        #expect(alerts.isEmpty)
    }

    @Test func noAlertForUsageOnlyWindows() {
        let claudePrev = UsageSnapshot(provider: .claude, windows: [UsageWindow(kind: .rolling, label: "5h", percent: nil, usedTokens: 1)], capturedAt: now, sourceLabel: "local logs")
        let claudeCur = UsageSnapshot(provider: .claude, windows: [UsageWindow(kind: .rolling, label: "5h", percent: nil, usedTokens: 999)], capturedAt: now, sourceLabel: "local logs")
        #expect(NotificationDecider.alerts(previous: [.claude: claudePrev], current: [.claude: claudeCur]).isEmpty)
    }

    @Test func firesFromUnknownPreviousWhenNewlyAbove() {
        let alerts = NotificationDecider.alerts(previous: [:], current: [.codex: codex(92)])
        #expect(Set(alerts.map(\.threshold)) == [70, 90])
    }
}
