import Testing
import Foundation
@testable import LLMeterCore

struct WindowLabelTests {
    // Pin English so titles are language-stable regardless of the test host's
    // system language (system mode now follows the OS preferred languages).
    init() { Localizer.shared.setCode("en") }

    @Test func mapsWindowKindToLocalizedTitle() {
        #expect(WindowLabel.localizedTitle(kind: .fiveHour, label: "5h") == "5-HOUR")
        #expect(WindowLabel.localizedTitle(kind: .weekly, label: "Weekly") == "WEEKLY")
        #expect(WindowLabel.localizedTitle(kind: .rolling, label: "5h") == "5H")
        #expect(WindowLabel.localizedTitle(kind: .rolling, label: "7d") == "7D")
        #expect(WindowLabel.localizedTitle(kind: .rolling, label: "Today") == "TODAY")
    }

    @Test func modelKeepsBrandNameButLocalizesSyntheticFallback() {
        // A real model/limit name is a brand — kept as-is (uppercased).
        #expect(WindowLabel.localizedTitle(kind: .model, label: "GPT-5.3-Codex-Spark") == "GPT-5.3-CODEX-SPARK")
        // The synthetic "model" placeholder (nil limit_name) is localized.
        #expect(WindowLabel.localizedTitle(kind: .model, label: "model") == "MODEL")
    }

    @Test func notificationAlertCarriesWindowKindForLocalizedTitle() {
        // The notification must render the SAME localized window title as the panel,
        // so the alert carries window kind (not just the raw English label).
        let now = Date()
        let prev = [ProviderID.codex: UsageSnapshot(
            provider: .codex, windows: [UsageWindow(kind: .weekly, label: "Weekly", percent: 50)],
            capturedAt: now, sourceLabel: "live")]
        let cur = [ProviderID.codex: UsageSnapshot(
            provider: .codex, windows: [UsageWindow(kind: .weekly, label: "Weekly", percent: 75)],
            capturedAt: now, sourceLabel: "live")]

        let alert = try! #require(NotificationDecider.alerts(previous: prev, current: cur).first)
        #expect(alert.windowKind == .weekly)
        #expect(WindowLabel.localizedTitle(kind: alert.windowKind, label: alert.windowLabel) == "WEEKLY")
    }
}
