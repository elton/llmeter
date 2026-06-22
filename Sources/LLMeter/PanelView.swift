import SwiftUI
import AppKit
import LLMeterCore

struct PanelView: View {
    let store: UsageStore
    @Bindable var settings: SettingsModel
    @State private var selection: PanelSection = .overview

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
        case .settings:
            SettingsView(model: settings)
        }
    }

    private var title: String {
        switch selection {
        case .overview: return "Overview"
        case .provider(let p): return p.displayName
        case .settings: return "Settings"
        }
    }
}
