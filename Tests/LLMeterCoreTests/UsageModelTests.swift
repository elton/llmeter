import Testing
import Foundation
@testable import LLMeterCore

struct UsageModelTests {
    @Test func severityThresholds() {
        #expect(Severity(percent: nil) == .unknown)
        #expect(Severity(percent: 0) == .normal)
        #expect(Severity(percent: 69.9) == .normal)
        #expect(Severity(percent: 70) == .warning)
        #expect(Severity(percent: 89.9) == .warning)
        #expect(Severity(percent: 90) == .critical)
        #expect(Severity(percent: 100) == .critical)
    }

    @Test func worstSeverityUsesMostCriticalPercentWindow() {
        let now = Date(timeIntervalSince1970: 1_782_000_000)
        let snap = UsageSnapshot(provider: .codex, windows: [
            UsageWindow(kind: .fiveHour, label: "5h", percent: 77),
            UsageWindow(kind: .weekly, label: "Weekly", percent: 12),
            UsageWindow(kind: .rolling, label: "5h", percent: nil, usedTokens: 1000)
        ], capturedAt: now, sourceLabel: "live")
        #expect(snap.worstSeverity == .warning)
    }

    @Test func worstSeverityIsUnknownWhenNoWindowHasPercent() {
        let now = Date(timeIntervalSince1970: 1_782_000_000)
        let snap = UsageSnapshot(provider: .claude, windows: [
            UsageWindow(kind: .rolling, label: "7d", percent: nil, usedTokens: 5000, estimatedCostUSD: 1.2)
        ], capturedAt: now, sourceLabel: "local logs")
        #expect(snap.worstSeverity == .unknown)
    }
}
