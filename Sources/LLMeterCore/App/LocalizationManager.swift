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
            let missing = "\u{0}llmeter.missing\u{0}"
            for candidate in [code, code.lowercased()] {
                guard let path = bundle.path(forResource: candidate, ofType: "lproj"),
                      let langBundle = Bundle(path: path) else { continue }
                let value = langBundle.localizedString(forKey: key, value: missing, table: nil)
                if value != missing { return value }
                break  // lproj exists but lacks the key → fall back to the base bundle
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
            localizer.setCode(language.code)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let localizer: Localizer
    static let defaultsKey = "llmeter.language"

    /// `localizer` is injectable so tests don't mutate the shared singleton's code
    /// (which would leak into other suites that resolve strings via `Localizer.shared`).
    public init(defaults: UserDefaults = .standard, localizer: Localizer = .shared) {
        self.defaults = defaults
        self.localizer = localizer
        let stored = defaults.string(forKey: Self.defaultsKey).flatMap(AppLanguage.init(rawValue:)) ?? .system
        self.language = stored
        localizer.setCode(stored.code)
    }
}
