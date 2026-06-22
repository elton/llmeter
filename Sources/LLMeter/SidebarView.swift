import SwiftUI
import LLMeterCore

enum PanelSection: Hashable {
    case overview
    case provider(ProviderID)
    case accounts
    case settings
}

struct SidebarView: View {
    @Binding var selection: PanelSection

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            item(.overview, "OVERVIEW", "gauge.with.dots.needle.50percent")
            item(.provider(.codex), "CODEX", "chevron.left.forwardslash.chevron.right")
            item(.provider(.claude), "CLAUDE", "sparkles")
            Spacer()
            item(.accounts, "ACCOUNTS", "person.crop.circle")
            item(.settings, "SETTINGS", "slider.horizontal.3")
        }
        .padding(10)
        .frame(width: 158)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func item(_ section: PanelSection, _ title: String, _ symbol: String) -> some View {
        Button {
            selection = section
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol).frame(width: 18)
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selection == section ? Color.primary.opacity(0.12) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(selection == section ? Color.primary : Color.secondary)
    }
}
