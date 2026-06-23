import Foundation

/// Per-file parse cache for Claude Code logs, keyed by URL + modification date.
///
/// Heavy users accumulate gigabytes of append-only `.jsonl` logs; re-reading and
/// re-parsing them on every poll dominated refresh time. This cache lets
/// `ClaudeProvider` re-parse only files whose mtime changed since last refresh, so a
/// steady-state refresh touches just the one or two logs being actively written.
///
/// Thread-safe: `fetch()` runs provider work off the main actor, so the cache is
/// guarded by a lock and marked `@unchecked Sendable`.
public final class ClaudeLogCache: @unchecked Sendable {
    private let lock = NSLock()
    private var store: [URL: (modifiedAt: Date, entries: [ClaudeUsageEntry])] = [:]

    public init() {}

    /// Returns cached entries when the file's modification date is unchanged;
    /// otherwise calls `parse`, stores the result, and returns it.
    public func entries(for url: URL, modifiedAt: Date,
                        parse: () -> [ClaudeUsageEntry]) -> [ClaudeUsageEntry] {
        lock.lock()
        if let hit = store[url], hit.modifiedAt == modifiedAt {
            let cached = hit.entries
            lock.unlock()
            return cached
        }
        lock.unlock()

        let parsed = parse()

        lock.lock()
        store[url] = (modifiedAt, parsed)
        lock.unlock()
        return parsed
    }

    /// Drops cache entries for files no longer in scope (deleted, or aged out of the
    /// window) so the cache cannot grow without bound.
    public func prune(keeping urls: Set<URL>) {
        lock.lock()
        store = store.filter { urls.contains($0.key) }
        lock.unlock()
    }
}
