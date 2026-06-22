import Foundation
import Observation

@MainActor
@Observable
public final class UsageStore {
    public private(set) var snapshots: [ProviderID: UsageSnapshot] = [:]
    public private(set) var lastRefresh: Date?
    public private(set) var isRefreshing = false

    @ObservationIgnored private let providers: [any QuotaProvider]
    @ObservationIgnored private var pollingTask: Task<Void, Never>?

    public init(providers: [any QuotaProvider]) {
        self.providers = providers
    }

    public var status: MenuBarStatus {
        var dict: [ProviderID: UsageSnapshot?] = [:]
        for provider in providers { dict[provider.id] = snapshots[provider.id] }
        return MenuBarStatusBuilder.build(from: dict)
    }

    /// Refreshes all providers. Fetches fan out concurrently (a slow Codex request
    /// never blocks Claude's local-log update) and results merge back on the main
    /// actor. If a sweep is already running, a concurrent caller skips rather than
    /// starting a second, interleaving sweep — so older results never overwrite
    /// newer ones. Cancellation (popover closed mid-fetch, `stopPolling()`)
    /// propagates into the in-flight `URLSession` work and leaves the store
    /// untouched, so a cancelled fetch never clears a still-good snapshot.
    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        await withTaskGroup(
            of: (ProviderID, Result<UsageSnapshot, ProviderError>).self
        ) { group in
            for provider in providers {
                group.addTask { (provider.id, await provider.fetch()) }
            }
            // Publish each provider's result the moment it arrives, so a slow or
            // hanging provider never holds back a fast one's update.
            for await (id, result) in group {
                // Cancellation is expected control flow, not an outage — skip so a
                // cancelled fetch never clears a still-good snapshot.
                if Task.isCancelled { continue }
                switch result {
                case .success(let snap):
                    snapshots[id] = snap
                case .failure:
                    // A genuine failure degrades this provider to unavailable rather
                    // than presenting a previously-cached snapshot as freshly refreshed.
                    snapshots[id] = nil
                }
            }
        }

        if Task.isCancelled { return }
        lastRefresh = Date()
    }

    /// Refreshes immediately, then every `interval` seconds until cancelled.
    public func startPolling(everySeconds interval: Int) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    public func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
