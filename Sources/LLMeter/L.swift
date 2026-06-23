import Foundation
import LLMeterCore

/// Localized string from the app bundle, honoring the runtime-selected language.
func L(_ key: String) -> String {
    Localizer.shared.localize(key, bundle: .module)
}

/// Localized format string with arguments (e.g. `L("provider.noData", name)`).
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: Localizer.shared.localize(key, bundle: .module), arguments: args)
}
