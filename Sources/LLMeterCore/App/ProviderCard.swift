import Foundation

public struct ProviderCard: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable, Equatable {
        case gauge   // percent ring (Codex windows)
        case usage   // token count + cost (Claude windows)
        case plain   // a labeled value (plan, credits)
    }

    public let id: String
    public let title: String
    public let kind: Kind
    public let percent: Double?
    public let value: String
    public let subtitle: String?
    public let severity: Severity

    public init(id: String, title: String, kind: Kind, percent: Double? = nil,
                value: String, subtitle: String? = nil, severity: Severity = .unknown) {
        self.id = id
        self.title = title
        self.kind = kind
        self.percent = percent
        self.value = value
        self.subtitle = subtitle
        self.severity = severity
    }
}
