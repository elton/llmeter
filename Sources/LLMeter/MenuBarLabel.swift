import SwiftUI
import LLMeterCore

struct MenuBarLabel: View {
    let status: MenuBarStatus

    var body: some View {
        Image(systemName: "gauge.with.dots.needle.50percent")
            .foregroundStyle(Color(severity: status.overall))
    }
}
