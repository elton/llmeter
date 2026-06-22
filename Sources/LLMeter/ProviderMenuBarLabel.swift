import SwiftUI
import LLMeterCore

struct ProviderMenuBarLabel: View {
    let label: ProviderLabel?

    var body: some View {
        Text(text)
            .foregroundStyle(Color(severity: label?.severity ?? .unknown))
    }

    private var text: String {
        guard let label else { return "—" }
        return "\(label.provider.displayName.prefix(1))·\(label.text)"
    }
}
