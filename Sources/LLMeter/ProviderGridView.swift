import SwiftUI
import LLMeterCore

struct ProviderGridView: View {
    let provider: ProviderID
    let store: UsageStore

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView {
            if let snapshot = store.snapshots[provider] {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(ProviderPanelBuilder.cards(for: snapshot, now: Date())) { card in
                        CardView(card: card)
                    }
                }
                .padding(14)
            } else {
                ContentUnavailableView(L("provider.unavailable"), systemImage: "wifi.slash",
                                       description: Text(L("provider.noData", provider.displayName)))
                    .padding(.top, 60)
            }
        }
    }
}
