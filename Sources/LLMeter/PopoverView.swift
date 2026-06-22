import SwiftUI
import AppKit
import LLMeterCore

struct PopoverView: View {
    let store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("LLMeter").font(.headline)
                Spacer()
                if let last = store.lastRefresh {
                    Text(last, style: .relative).font(.caption).foregroundStyle(.secondary)
                }
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(store.isRefreshing)
            }

            ForEach(ProviderID.allCases, id: \.self) { provider in
                providerSection(provider)
            }

            Divider()
            Button("Quit LLMeter") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 300)
        .task { await store.refresh() }
    }

    @ViewBuilder
    private func providerSection(_ provider: ProviderID) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(provider.displayName.uppercased())
                .font(.caption).foregroundStyle(.secondary)

            if let snap = store.snapshots[provider] {
                ForEach(Array(snap.windows.enumerated()), id: \.offset) { _, window in
                    HStack {
                        Text(window.label)
                        Spacer()
                        Text(valueText(window))
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            } else {
                Text("unavailable").font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private func valueText(_ window: UsageWindow) -> String {
        if let pct = window.percent { return "\(Int(pct))%" }
        if let tokens = window.usedTokens { return MenuBarStatusBuilder.compact(tokens) + " tok" }
        return "—"
    }
}
