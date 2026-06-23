import Foundation

public struct ClaudeProvider: QuotaProvider {
    public let id: ProviderID = .claude

    private let clock: Clock
    private let projectsDir: URL
    private let cache: ClaudeLogCache

    public init(clock: Clock = SystemClock(),
                projectsDir: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/projects"),
                cache: ClaudeLogCache = ClaudeLogCache()) {
        self.clock = clock
        self.projectsDir = projectsDir
        self.cache = cache
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
        // The widest window we report is 7 days. Claude Code logs are append-only, so
        // a file last modified before that window cannot hold any in-window entry —
        // skip it instead of re-reading the entire history (gigabytes for heavy users)
        // on every refresh. The 1h slack absorbs clock/timezone skew at the boundary.
        let cutoff = clock.now.addingTimeInterval(-7 * 86400 - 3600)
        guard let en = fm.enumerator(at: projectsDir,
                                     includingPropertiesForKeys: [.contentModificationDateKey],
                                     options: [.skipsHiddenFiles]) else { return [] }
        var entries: [ClaudeUsageEntry] = []
        var seen: Set<URL> = []
        for case let url as URL in en where url.pathExtension == "jsonl" {
            let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let mod, mod < cutoff { continue }
            guard let mod else {
                // No mtime to key the cache on — read directly, uncached.
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    entries.append(contentsOf: ClaudeLogParser.entries(fromJSONL: content))
                }
                continue
            }
            // Re-parse only when the file changed since last refresh; otherwise reuse.
            seen.insert(url)
            entries.append(contentsOf: cache.entries(for: url, modifiedAt: mod) {
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
                return ClaudeLogParser.entries(fromJSONL: content)
            })
        }
        cache.prune(keeping: seen)
        return entries
    }
}
