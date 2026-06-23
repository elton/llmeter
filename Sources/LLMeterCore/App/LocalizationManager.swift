import Foundation
import Observation

/// Thread-safe current-language snapshot + string lookup, callable from any actor.
///
/// Core builders (ProviderPanelBuilder, ResetCountdown, …) assemble user-facing text
/// and may run off the main actor, so the lookup must be nonisolated. `.strings`/`.lproj`
/// is the only localization format SwiftPM's CLI (`swift build`) actually compiles —
/// String Catalogs (`.xcstrings`) are copied but not compiled, so `NSLocalizedString`
/// returns the key. For a manual override we load the chosen language's `.lproj`
/// directly; for system we fall through to default (OS-preferred) resolution.
public final class Localizer: @unchecked Sendable {
    public static let shared = Localizer()

    private let lock = NSLock()
    private var code: String?   // nil = follow the system language

    public init() {}

    public func setCode(_ newCode: String?) { lock.withLock { code = newCode } }
    private func currentCode() -> String? { lock.withLock { code } }

    public func localize(_ key: String, bundle: Bundle) -> String {
        if let code = currentCode() {
            // Try the exact code, then the lowercase variant — SwiftPM lowercases the
            // region subtag (zh-Hans → zh-hans). Identical codes just hit on the first.
            for candidate in [code, code.lowercased()] {
                if let path = bundle.path(forResource: candidate, ofType: "lproj"),
                   let langBundle = Bundle(path: path) {
                    return langBundle.localizedString(forKey: key, value: key, table: nil)
                }
            }
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

/// SwiftUI-facing language state. Persists the choice and mirrors it into `Localizer`
/// so off-actor lookups see the same language. `@Observable` so views re-render when
/// the language changes (switching takes effect without a relaunch).
@MainActor
@Observable
public final class LocalizationManager {
    public static let shared = LocalizationManager()

    public var language: AppLanguage {
        didSet {
            guard language != oldValue else { return }
            defaults.set(language.rawValue, forKey: Self.defaultsKey)
            Localizer.shared.setCode(language.code)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    static let defaultsKey = "llmeter.language"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Self.defaultsKey).flatMap(AppLanguage.init(rawValue:)) ?? .system
        self.language = stored
        Localizer.shared.setCode(stored.code)
    }
}
