import Testing
import Foundation
@testable import LLMeterCore

@MainActor
struct SettingsModelTests {
    private func freshStore() -> UserDefaultsSettingsStore {
        UserDefaultsSettingsStore(defaults: UserDefaults(suiteName: "llmeter-tests-\(UUID().uuidString)")!)
    }

    @Test func loadsInitialAndPersistsChanges() {
        let store = freshStore()
        let model = SettingsModel(store: store)
        #expect(model.settings.displayMode == .singleIcon)

        model.settings.displayMode = .multiIcon
        #expect(store.load().displayMode == .multiIcon)   // persisted immediately
    }
}
