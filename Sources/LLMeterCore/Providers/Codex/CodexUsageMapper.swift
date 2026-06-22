import Foundation

public enum CodexUsageMapper {
    private struct Response: Decodable {
        let plan_type: String?
        let rate_limit: RateLimit?
        let additional_rate_limits: [AdditionalLimit]?
        let credits: Credits?

        struct RateLimit: Decodable {
            let primary_window: Window?
            let secondary_window: Window?
        }
        struct Window: Decodable {
            let used_percent: Double
            let reset_after_seconds: Double?
            let reset_at: Double?
        }
        struct AdditionalLimit: Decodable {
            let limit_name: String?
            let rate_limit: RateLimit?
        }
        struct Credits: Decodable {
            let balance: String?
        }
    }

    public static func snapshot(from data: Data, capturedAt: Date, sourceLabel: String) throws -> UsageSnapshot {
        let r = try JSONDecoder().decode(Response.self, from: data)
        var windows: [UsageWindow] = []

        if let p = r.rate_limit?.primary_window {
            windows.append(UsageWindow(kind: .fiveHour, label: "5h", percent: p.used_percent,
                                       resetsAt: resetDate(p, capturedAt)))
        }
        if let s = r.rate_limit?.secondary_window {
            windows.append(UsageWindow(kind: .weekly, label: "Weekly", percent: s.used_percent,
                                       resetsAt: resetDate(s, capturedAt)))
        }
        for extra in r.additional_rate_limits ?? [] {
            if let p = extra.rate_limit?.primary_window {
                windows.append(UsageWindow(kind: .model, label: extra.limit_name ?? "model",
                                           percent: p.used_percent, resetsAt: resetDate(p, capturedAt)))
            }
        }

        return UsageSnapshot(provider: .codex, planType: r.plan_type, windows: windows,
                             creditsBalance: r.credits?.balance, capturedAt: capturedAt,
                             isStale: false, sourceLabel: sourceLabel)
    }

    private static func resetDate(_ window: Response.Window, _ capturedAt: Date) -> Date? {
        if let at = window.reset_at { return Date(timeIntervalSince1970: at) }
        if let after = window.reset_after_seconds { return capturedAt.addingTimeInterval(after) }
        return nil
    }
}
