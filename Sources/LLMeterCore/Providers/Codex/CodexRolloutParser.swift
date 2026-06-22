import Foundation

public enum CodexRolloutParser {
    private struct RateLimits: Decodable {
        let primary: Window?
        let secondary: Window?
        struct Window: Decodable {
            let used_percent: Double
            let resets_at: Double?
        }
    }

    /// Scans JSONL content, returns a snapshot from the LAST line that carries a
    /// `rate_limits` object (top-level or under `payload`). Returns nil if none.
    public static func snapshot(fromJSONL content: String, capturedAt: Date) -> UsageSnapshot? {
        var last: RateLimits?
        for rawLine in content.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = Data(rawLine.utf8)
            guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let rlDict = rateLimitsDict(in: obj),
                  let rlData = try? JSONSerialization.data(withJSONObject: rlDict),
                  let parsed = try? JSONDecoder().decode(RateLimits.self, from: rlData)
            else { continue }
            last = parsed
        }

        guard let rl = last else { return nil }
        var windows: [UsageWindow] = []
        if let p = rl.primary {
            windows.append(UsageWindow(kind: .fiveHour, label: "5h", percent: p.used_percent,
                                       resetsAt: p.resets_at.map { Date(timeIntervalSince1970: $0) }))
        }
        if let s = rl.secondary {
            windows.append(UsageWindow(kind: .weekly, label: "Weekly", percent: s.used_percent,
                                       resetsAt: s.resets_at.map { Date(timeIntervalSince1970: $0) }))
        }
        guard !windows.isEmpty else { return nil }

        return UsageSnapshot(provider: .codex, windows: windows, capturedAt: capturedAt,
                             isStale: true, sourceLabel: "local cache")
    }

    private static func rateLimitsDict(in obj: [String: Any]) -> [String: Any]? {
        if let rl = obj["rate_limits"] as? [String: Any] { return rl }
        if let payload = obj["payload"] as? [String: Any],
           let rl = payload["rate_limits"] as? [String: Any] { return rl }
        return nil
    }
}
