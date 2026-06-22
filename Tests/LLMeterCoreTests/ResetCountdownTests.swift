import Testing
import Foundation
@testable import LLMeterCore

struct ResetCountdownTests {
    private let now = Date(timeIntervalSince1970: 1_782_000_000)

    @Test func nilWhenNoResetDate() {
        #expect(ResetCountdown.format(nil, now: now) == nil)
    }

    @Test func minutesOnly() {
        #expect(ResetCountdown.format(now.addingTimeInterval(41 * 60), now: now) == "resets in 41m")
    }

    @Test func hoursAndMinutes() {
        #expect(ResetCountdown.format(now.addingTimeInterval(2 * 3600 + 30 * 60), now: now) == "resets in 2h 30m")
    }

    @Test func daysAndHours() {
        #expect(ResetCountdown.format(now.addingTimeInterval(6 * 86400 + 20 * 3600), now: now) == "resets in 6d 20h")
    }

    @Test func pastIsNow() {
        #expect(ResetCountdown.format(now.addingTimeInterval(-10), now: now) == "resets now")
    }
}
