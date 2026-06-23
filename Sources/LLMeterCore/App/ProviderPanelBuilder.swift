import Foundation

public enum ProviderPanelBuilder {
    public static func cards(for snapshot: UsageSnapshot, now: Date) -> [ProviderCard] {
        switch snapshot.provider {
        case .codex: return codexCards(snapshot, now: now)
        case .claude: return claudeCards(snapshot)
        }
    }

    private static func codexCards(_ snapshot: UsageSnapshot, now: Date) -> [ProviderCard] {
        var cards: [ProviderCard] = []
        for window in snapshot.windows {
            let idSuffix: String
            switch window.kind {
            case .fiveHour: idSuffix = "fiveHour"
            case .weekly:   idSuffix = "weekly"
            case .model:    idSuffix = "model-\(window.label)"
            case .rolling:  idSuffix = "rolling-\(window.label)"
            }
            cards.append(ProviderCard(
                id: "codex-\(idSuffix)",
                title: WindowLabel.localizedTitle(kind: window.kind, label: window.label),
                kind: .gauge,
                percent: window.percent,
                value: ProviderCard.remainingValue(usedPercent: window.percent),
                subtitle: ResetCountdown.format(window.resetsAt, now: now),
                severity: window.severity
            ))
        }
        if let plan = snapshot.planType {
            cards.append(ProviderCard(id: "codex-plan", title: L("card.plan"), kind: .plain,
                                      value: prettyPlan(plan)))
        }
        if let credits = snapshot.creditsBalance {
            cards.append(ProviderCard(id: "codex-credits", title: L("card.credits"), kind: .plain,
                                      value: "$\(credits)"))
        }
        return cards
    }

    private static func claudeCards(_ snapshot: UsageSnapshot) -> [ProviderCard] {
        snapshot.windows.map { window in
            let tokens = window.usedTokens ?? 0
            let cost = window.estimatedCostUSD.map { String(format: "~$%.2f", $0) }
            return ProviderCard(
                id: "claude-\(window.label)",
                title: WindowLabel.localizedTitle(kind: window.kind, label: window.label),
                kind: .usage,
                percent: nil,
                value: L("card.tokens", MenuBarStatusBuilder.compact(tokens)),
                subtitle: cost,
                severity: .unknown
            )
        }
    }

    private static func prettyPlan(_ raw: String) -> String {
        switch raw.lowercased() {
        case "prolite": return "Pro Lite"
        case "pro": return "Pro"
        case "plus": return "Plus"
        case "max": return "Max"
        default: return raw.capitalized
        }
    }
}
