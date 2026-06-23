import Foundation

/// Localized title for a usage window, shared by the panel, overview, and
/// notifications so the same window never shows different names across surfaces.
public enum WindowLabel {
    public static func localizedTitle(kind: WindowKind, label: String) -> String {
        switch kind {
        case .fiveHour: return L("window.fiveHour")
        case .weekly:   return L("window.weekly")
        case .model:    return label == "model" ? L("window.model") : label.uppercased()
        case .rolling:
            switch label {
            case "5h":    return L("window.claude.5h")
            case "7d":    return L("window.claude.7d")
            case "Today": return L("window.claude.today")
            default:      return label.uppercased()
            }
        }
    }
}
