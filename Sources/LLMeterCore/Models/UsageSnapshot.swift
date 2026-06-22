import Foundation

public enum ProviderID: String, Sendable, CaseIterable, Codable {
    case codex
    case claude

    public var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .claude: return "Claude"
        }
    }
}

public enum WindowKind: String, Sendable, Codable {
    case fiveHour   // 5-hour rolling quota window
    case weekly     // 7-day quota window
    case model      // per-model sub-limit
    case rolling    // local usage estimate window (no quota %)
}

public enum Severity: String, Sendable {
    case normal     // < 70%
    case warning    // >= 70%
    case critical   // >= 90%
    case unknown    // no percent available

    public init(percent: Double?) {
        guard let p = percent else { self = .unknown; return }
        switch p {
        case ..<70: self = .normal
        case ..<90: self = .warning
        default:    self = .critical
        }
    }
}

public struct UsageWindow: Sendable, Equatable {
    public let kind: WindowKind
    public let label: String
    public let percent: Double?          // 0...100; nil for usage-only (Claude)
    public let resetsAt: Date?           // nil when unknown
    public let usedTokens: Int?          // for usage-estimate windows
    public let estimatedCostUSD: Double? // for usage-estimate windows

    public init(kind: WindowKind, label: String, percent: Double? = nil,
                resetsAt: Date? = nil, usedTokens: Int? = nil, estimatedCostUSD: Double? = nil) {
        self.kind = kind
        self.label = label
        self.percent = percent
        self.resetsAt = resetsAt
        self.usedTokens = usedTokens
        self.estimatedCostUSD = estimatedCostUSD
    }

    public var severity: Severity { Severity(percent: percent) }
}

public struct UsageSnapshot: Sendable, Equatable {
    public let provider: ProviderID
    public let planType: String?
    public let windows: [UsageWindow]
    public let creditsBalance: String?
    public let capturedAt: Date
    public let isStale: Bool              // true when from a local fallback cache
    public let sourceLabel: String        // "live" | "local cache" | "local logs"

    public init(provider: ProviderID, planType: String? = nil, windows: [UsageWindow],
                creditsBalance: String? = nil, capturedAt: Date,
                isStale: Bool = false, sourceLabel: String) {
        self.provider = provider
        self.planType = planType
        self.windows = windows
        self.creditsBalance = creditsBalance
        self.capturedAt = capturedAt
        self.isStale = isStale
        self.sourceLabel = sourceLabel
    }

    /// Most severe severity among windows that carry a percent. `.unknown` if none do.
    public var worstSeverity: Severity {
        let withPercent = windows.filter { $0.percent != nil }
        guard !withPercent.isEmpty else { return .unknown }
        let sevs = withPercent.map { Severity(percent: $0.percent) }
        if sevs.contains(.critical) { return .critical }
        if sevs.contains(.warning) { return .warning }
        return .normal
    }
}
