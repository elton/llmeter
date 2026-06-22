import Testing
import Foundation
@testable import LLMeterCore

struct AppSettingsTests {
    private func freshStore() -> UserDefaultsSettingsStore {
        let defaults = UserDefaults(suiteName: "llmeter-tests-\(UUID().uuidString)")!
        return UserDefaultsSettingsStore(defaults: defaults)
    }

    @Test func defaultsWhenEmpty() {
        let s = freshStore().load()
        #expect(s.displayMode == .singleIcon)
        #expect(s.pollIntervalSeconds == 300)
        #expect(s.notificationsEnabled == true)
    }

    @Test func roundTripsThroughDefaults() {
        let store = freshStore()
        store.save(AppSettings(displayMode: .multiIcon, pollIntervalSeconds: 120, notificationsEnabled: false))
        let loaded = store.load()
        #expect(loaded.displayMode == .multiIcon)
        #expect(loaded.pollIntervalSeconds == 120)
        #expect(loaded.notificationsEnabled == false)
    }
}
