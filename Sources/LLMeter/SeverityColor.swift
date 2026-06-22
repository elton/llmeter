import SwiftUI
import LLMeterCore

extension Color {
    /// Shared severity → color mapping used by the menu-bar icons and gauge rings.
    init(severity: Severity) {
        switch severity {
        case .normal:   self = .green
        case .warning:  self = .orange
        case .critical: self = .red
        case .unknown:  self = .secondary
        }
    }
}
