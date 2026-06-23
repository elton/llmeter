import SwiftUI
import AppKit
import LLMeterCore

struct PanelView: View {
    let store: UsageStore
    @Bindable var settings: SettingsModel
    let codexStore: CodexCredentialStore
    let login: CodexLoginService
    @Binding var selection: PanelSection

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selection: $selection)
            Divider()
            VStack(spacing: 0) {
                header
                Divider()
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 560, height: 380)
        .task { await store.refresh() }
        // Rebuild the whole panel when the language changes so every L(...) re-resolves.
        .id(LocalizationManager.shared.language)
    }

    private var header: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            if let last = store.lastRefresh {
                Text(last, style: .relative).font(.caption).foregroundStyle(.secondary)
            }
            Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless)
                .disabled(store.isRefreshing)
        }
        .padding(12)
    }

    @ViewBuilder private var content: some View {
        switch selection {
        case .overview:
            OverviewView(store: store)
        case .provider(let provider):
            ProviderGridView(provider: provider, store: store)
        case .accounts:
            AccountsView(store: codexStore, login: login)
        case .settings:
            SettingsView(model: settings)
        }
    }

    private var title: String {
        switch selection {
        case .overview: return L("panel.overview")
        case .provider(let p): return p.displayName
        case .accounts: return L("panel.accounts")
        case .settings: return L("panel.settings")
        }
    }
}
