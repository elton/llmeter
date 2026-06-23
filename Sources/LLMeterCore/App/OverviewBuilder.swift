import Foundation

public enum OverviewBuilder {
    public static func cards(from snapshots: [ProviderID: UsageSnapshot?], now: Date) -> [ProviderCard] {
        ProviderID.allCases.map { provider in
            guard let maybe = snapshots[provider], let snap = maybe else {
                return ProviderCard(id: "overview-\(provider.rawValue)", title: provider.displayName.uppercased(),
                                    kind: .plain, value: "—", severity: .unknown)
            }
            // Codex: worst percent window as a gauge. Claude: the widest usage
            // window (most tokens = the 7-day total), independent of window order.
            if let worst = snap.windows.filter({ $0.percent != nil }).max(by: { ($0.percent ?? 0) < ($1.percent ?? 0) }) {
                return ProviderCard(
                    id: "overview-\(provider.rawValue)", title: provider.displayName.uppercased(),
                    kind: .gauge, percent: worst.percent,
                    value: ProviderCard.remainingValue(usedPercent: worst.percent),
                    subtitle: ResetCountdown.format(worst.resetsAt, now: now), severity: worst.severity
                )
            }
            // Most tokens = the widest window (7d). Break token ties by cost, since
            // usedTokens excludes cache reads but cost includes them — so the 7-day
            // window (highest cost) still wins over 5h/Today on an equal-token tie.
            let usage = snap.windows.filter { $0.usedTokens != nil }.max { lhs, rhs in
                let lt = lhs.usedTokens ?? 0, rt = rhs.usedTokens ?? 0
                if lt != rt { return lt < rt }
                return (lhs.estimatedCostUSD ?? 0) < (rhs.estimatedCostUSD ?? 0)
            }
            let tokens = usage?.usedTokens ?? 0
            return ProviderCard(
                id: "overview-\(provider.rawValue)", title: provider.displayName.uppercased(),
                kind: .usage, value: L("card.tokens", MenuBarStatusBuilder.compact(tokens)),
                subtitle: usage?.estimatedCostUSD.map { String(format: "~$%.2f", $0) }, severity: .unknown
            )
        }
    }
}
