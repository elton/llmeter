import Foundation

public struct ProviderLabel: Equatable, Sendable {
    public let provider: ProviderID
    public let text: String
    public let severity: Severity

    public init(provider: ProviderID, text: String, severity: Severity) {
        self.provider = provider
        self.text = text
        self.severity = severity
    }
}

public struct MenuBarStatus: Equatable, Sendable {
    public let overall: Severity
    public let providers: [ProviderLabel]

    public init(overall: Severity, providers: [ProviderLabel]) {
        self.overall = overall
        self.providers = providers
    }
}

public enum MenuBarStatusBuilder {
    /// Builds the menu-bar representation. Providers are emitted in `ProviderID.allCases`
    /// order. Overall severity considers only providers that carry a percent.
    public static func build(from snapshots: [ProviderID: UsageSnapshot?]) -> MenuBarStatus {
        var labels: [ProviderLabel] = []
        for provider in ProviderID.allCases {
            guard let maybe = snapshots[provider], let snap = maybe else {
                labels.append(ProviderLabel(provider: provider, text: "—", severity: .unknown))
                continue
            }
            labels.append(ProviderLabel(provider: provider, text: label(for: snap), severity: snap.worstSeverity))
        }

        let severities = labels.map(\.severity).filter { $0 != .unknown }
        let overall: Severity
        if severities.contains(.critical) { overall = .critical }
        else if severities.contains(.warning) { overall = .warning }
        else if !severities.isEmpty { overall = .normal }
        else { overall = .unknown }

        return MenuBarStatus(overall: overall, providers: labels)
    }

    static func label(for snapshot: UsageSnapshot) -> String {
        if let pct = snapshot.windows.compactMap(\.percent).max() {
            return "\(Int(pct))%"
        }
        if let tokens = snapshot.windows.first(where: { $0.usedTokens != nil })?.usedTokens {
            return compact(tokens)
        }
        return "—"
    }

    public static func compact(_ n: Int) -> String {
        let d = Double(n)
        switch n {
        case 1_000_000_000...: return String(format: "%.1fB", d / 1e9)
        case 1_000_000...:     return String(format: "%.0fM", d / 1e6)
        case 1_000...:         return String(format: "%.0fK", d / 1e3)
        default:               return "\(n)"
        }
    }
}
