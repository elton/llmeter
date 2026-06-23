import Foundation

/// The languages LLMeter ships translations for, plus `.system` (follow macOS).
public enum AppLanguage: String, CaseIterable, Sendable, Codable {
    case system
    case en
    case zhHans = "zh-Hans"
    case ja
    case ko

    /// The `.lproj` language code to load, or nil to follow the system preference.
    public var code: String? {
        self == .system ? nil : rawValue
    }

    /// Endonym (the language's own name), used in the picker. `.system` is the only
    /// entry that must itself be localized, via the `language.system` key.
    public var endonym: String {
        switch self {
        case .system: return "System"   // overridden by a localized lookup in the UI
        case .en:     return "English"
        case .zhHans: return "简体中文"
        case .ja:     return "日本語"
        case .ko:     return "한국어"
        }
    }
}
