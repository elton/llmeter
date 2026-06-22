import Foundation

public enum OverviewBuilder {
    public static func cards(from snapshots: [ProviderID: UsageSnapshot?], now: Date) -> [ProviderCard] {
        ProviderID.allCases.map { provider in
            guard let maybe = snapshots[provider], let snap = maybe else {
                return ProviderCard(id: "overview-\(provider.rawValue)", title: provider.displayName.uppercased(),
                                    kind: .plain, value: "—", severity: .unknown)
            }
            // Codex: worst percent window as a gauge. Claude: last (widest) usage window.
            if let worst = snap.windows.filter({ $0.percent != nil }).max(by: { ($0.percent ?? 0) < ($1.percent ?? 0) }) {
                return ProviderCard(
                    id: "overview-\(provider.rawValue)", title: provider.displayName.uppercased(),
                    kind: .gauge, percent: worst.percent, value: "\(Int(worst.percent ?? 0))%",
                    subtitle: ResetCountdown.format(worst.resetsAt, now: now), severity: worst.severity
                )
            }
            let usage = snap.windows.last(where: { $0.usedTokens != nil })
            let tokens = usage?.usedTokens ?? 0
            return ProviderCard(
                id: "overview-\(provider.rawValue)", title: provider.displayName.uppercased(),
                kind: .usage, value: "\(MenuBarStatusBuilder.compact(tokens)) tok",
                subtitle: usage?.estimatedCostUSD.map { String(format: "~$%.2f", $0) }, severity: .unknown
            )
        }
    }
}
