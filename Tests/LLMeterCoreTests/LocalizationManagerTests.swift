import Testing
import Foundation
@testable import LLMeterCore

@MainActor
struct LocalizationManagerTests {
    private func tempDefaults() -> UserDefaults {
        UserDefaults(suiteName: "llmeter-test-\(UUID().uuidString)")!
    }

    @Test func defaultsToSystemWhenNothingStored() {
        let m = LocalizationManager(defaults: tempDefaults(), localizer: Localizer())
        #expect(m.language == .system)
        #expect(m.language.code == nil)
    }

    @Test func persistsAndReloadsChosenLanguage() {
        let defaults = tempDefaults()
        LocalizationManager(defaults: defaults, localizer: Localizer()).language = .ja
        let reloaded = LocalizationManager(defaults: defaults, localizer: Localizer())
        #expect(reloaded.language == .ja)
        #expect(reloaded.language.code == "ja")
    }

    @Test func codeMapsRegionSubtag() {
        #expect(AppLanguage.zhHans.code == "zh-Hans")
        #expect(AppLanguage.system.code == nil)
    }

    @Test func localizerFallsBackToKeyWhenTranslationMissing() {
        let loc = Localizer()
        loc.setCode("ja")
        // The test bundle has no ja.lproj entry for this key → returns the key itself.
        #expect(loc.localize("totally.missing.key", bundle: .module) == "totally.missing.key")
    }
}
