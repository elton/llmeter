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
        let code = currentCode()
        let manual = code != nil
        // Manual: the chosen language (+ lowercase region variant, since SwiftPM
        // lowercases zh-Hans → zh-hans). System: the OS preferred languages, matched
        // against the available lprojs ourselves — Bundle's own resolution keys off
        // the main bundle's CFBundleLocalizations, which a hand-assembled .app lacks,
        // so it would otherwise fall back to English even on a Chinese system.
        let candidates: [String]
        if let code {
            candidates = code == code.lowercased() ? [code] : [code, code.lowercased()]
        } else {
            candidates = Self.systemCandidates()
        }
        let missing = "\u{0}llmeter.missing\u{0}"
        for candidate in candidates {
            guard let path = bundle.path(forResource: candidate, ofType: "lproj"),
                  let langBundle = Bundle(path: path) else { continue }
            let value = langBundle.localizedString(forKey: key, value: missing, table: nil)
            if value != missing { return value }
            if manual { break }  // manual: key absent → base bundle; system: try next language
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// OS preferred languages expanded to lproj-name candidates, most-specific first:
    /// "zh-Hans-JP" → zh-Hans-JP, zh-hans-jp, zh-Hans, zh-hans, zh.
    private static func systemCandidates() -> [String] {
        var out: [String] = []
        for tag in Locale.preferredLanguages {
            let parts = tag.split(separator: "-").map(String.init)
            var n = parts.count
            while n >= 1 {
                let prefix = parts.prefix(n).joined(separator: "-")
                out.append(prefix)
                let lower = prefix.lowercased()
                if lower != prefix { out.append(lower) }
                n -= 1
            }
        }
        return out
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
