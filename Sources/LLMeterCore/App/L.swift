import Foundation

/// Localized string from LLMeterCore's own bundle, honoring the runtime language.
///
/// Internal to LLMeterCore so it never clashes with the app target's own `L(_:)`
/// (each resolves against its own `Bundle.module`). Core builders run off the main
/// actor, so this stays nonisolated via `Localizer`.
func L(_ key: String) -> String {
    Localizer.shared.localize(key, bundle: .module)
}

/// Localized format string with arguments (e.g. `L("reset.days", days, hours)`).
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: Localizer.shared.localize(key, bundle: .module), arguments: args)
}
