import Foundation

public struct ClaudeProvider: QuotaProvider {
    public let id: ProviderID = .claude

    private let clock: Clock
    private let projectsDir: URL

    public init(clock: Clock = SystemClock(),
                projectsDir: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/projects")) {
        self.clock = clock
        self.projectsDir = projectsDir
    }

    public func fetch() async -> Result<UsageSnapshot, ProviderError> {
        let entries = loadAllEntries()
        let now = clock.now

        func window(_ label: String, since: Date) -> UsageWindow {
            let slice = entries.filter { $0.timestamp >= since && $0.timestamp <= now }
            let tokens = slice.reduce(0) { $0 + $1.tokensExcludingCacheReads }
            let cost = slice.reduce(0.0) { $0 + ClaudePricing.cost($1) }
            return UsageWindow(kind: .rolling, label: label, percent: nil, resetsAt: nil,
                               usedTokens: tokens, estimatedCostUSD: cost)
        }

        let windows = [
            window("5h", since: now.addingTimeInterval(-5 * 3600)),
            window("7d", since: now.addingTimeInterval(-7 * 86400)),
            window("Today", since: Calendar.current.startOfDay(for: now)),
        ]

        return .success(UsageSnapshot(provider: .claude, windows: windows, capturedAt: now,
                                      isStale: false, sourceLabel: "local logs"))
    }

    private func loadAllEntries() -> [ClaudeUsageEntry] {
        let fm = FileManager.default
        guard let en = fm.enumerator(at: projectsDir,
                                     includingPropertiesForKeys: nil,
                                     options: [.skipsHiddenFiles]) else { return [] }
        var entries: [ClaudeUsageEntry] = []
        for case let url as URL in en where url.pathExtension == "jsonl" {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                entries.append(contentsOf: ClaudeLogParser.entries(fromJSONL: content))
            }
        }
        return entries
    }
}
