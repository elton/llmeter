import SwiftUI
import LLMeterCore

struct MenuBarLabel: View {
    let status: MenuBarStatus

    var body: some View {
        Image(systemName: "gauge.with.dots.needle.50percent")
            .foregroundStyle(color(for: status.overall))
    }

    private func color(for severity: Severity) -> Color {
        switch severity {
        case .normal:   return .green
        case .warning:  return .orange
        case .critical: return .red
        case .unknown:  return .secondary
        }
    }
}
