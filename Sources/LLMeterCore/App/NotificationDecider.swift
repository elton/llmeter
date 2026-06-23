import Foundation

public struct QuotaAlert: Equatable, Sendable, Identifiable {
    public let id: String
    public let provider: ProviderID
    public let windowKind: WindowKind
    public let windowLabel: String
    public let threshold: Int
    public let percent: Double

    public init(id: String, provider: ProviderID, windowKind: WindowKind, windowLabel: String, threshold: Int, percent: Double) {
        self.id = id
        self.provider = provider
        self.windowKind = windowKind
        self.windowLabel = windowLabel
        self.threshold = threshold
        self.percent = percent
    }
}

public enum NotificationDecider {
    private static let thresholds = [70, 90]

    /// Alerts for percent windows that rose across 70% or 90% since the previous snapshot.
    public static func alerts(previous: [ProviderID: UsageSnapshot],
                              current: [ProviderID: UsageSnapshot]) -> [QuotaAlert] {
        var out: [QuotaAlert] = []
        for (provider, cur) in current {
            let prevWindows = previous[provider]?.windows ?? []
            for window in cur.windows {
                guard let curPct = window.percent else { continue }
                let prevPct = prevWindows.first { $0.kind == window.kind && $0.label == window.label }?.percent ?? 0
                for threshold in thresholds where prevPct < Double(threshold) && curPct >= Double(threshold) {
                    out.append(QuotaAlert(
                        id: "\(provider.rawValue)-\(window.kind.rawValue)-\(window.label)-\(threshold)",
                        provider: provider, windowKind: window.kind, windowLabel: window.label,
                        threshold: threshold, percent: curPct
                    ))
                }
            }
        }
        return out.sorted { $0.id < $1.id }
    }
}
