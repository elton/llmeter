import SwiftUI
import LLMeterCore

struct OverviewView: View {
    let store: UsageStore

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(OverviewBuilder.cards(from: snapshotMap, now: Date())) { card in
                    CardView(card: card)
                }
            }
            .padding(14)
        }
    }

    private var snapshotMap: [ProviderID: UsageSnapshot?] {
        var map: [ProviderID: UsageSnapshot?] = [:]
        for provider in ProviderID.allCases { map[provider] = store.snapshots[provider] }
        return map
    }
}
