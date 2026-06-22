import SwiftUI
import LLMeterCore

struct ProviderMenuBarLabel: View {
    let label: ProviderLabel?

    var body: some View {
        Text(text)
    }

    private var text: String {
        guard let label else { return "—" }
        return "\(label.provider.displayName.prefix(1))·\(label.text)"
    }
}
