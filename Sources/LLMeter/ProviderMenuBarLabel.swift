import SwiftUI
import LLMeterCore

struct ProviderMenuBarLabel: View {
    let provider: ProviderID
    let label: ProviderLabel?

    var body: some View {
        Text("\(code)·\(label?.text ?? "—")")
            .foregroundStyle(Color(severity: label?.severity ?? .unknown))
    }

    private var code: String {
        switch provider {
        case .codex: return "Cx"
        case .claude: return "Cl"
        }
    }
}
