import SwiftUI
import LLMeterCore

struct CardView: View {
    let card: ProviderCard

    var body: some View {
        VStack(spacing: 8) {
            Text(card.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            center

            Text(card.value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let subtitle = card.subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.06)))
    }

    @ViewBuilder private var center: some View {
        switch card.kind {
        case .gauge:
            GaugeRing(percent: card.percent ?? 0, severity: card.severity)
        case .usage:
            Image(systemName: "chart.bar.xaxis").font(.title).foregroundStyle(.tint)
                .frame(height: 58)
        case .plain:
            Image(systemName: "creditcard").font(.title).foregroundStyle(.secondary)
                .frame(height: 58)
        }
    }
}
