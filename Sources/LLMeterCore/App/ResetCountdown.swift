import Foundation

public enum ResetCountdown {
    /// Human-friendly "resets in …" string, or nil when no reset time is known.
    public static func format(_ resetsAt: Date?, now: Date) -> String? {
        guard let resetsAt else { return nil }
        let total = Int(resetsAt.timeIntervalSince(now))
        if total <= 0 { return L("reset.now") }
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 { return L("reset.days", days, hours) }
        if hours > 0 { return L("reset.hours", hours, minutes) }
        return L("reset.minutes", minutes)
    }
}
