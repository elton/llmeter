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

    /// Refreshes all providers. Runs inline in the caller's task so cancellation
    /// (SwiftUI cancelling the popover `.task`, or `stopPolling()`) propagates into
    /// in-flight provider work. If a sweep is already running, a concurrent caller
    /// skips instead of starting a second, interleaving sweep — so older results
    /// can never overwrite newer ones.
    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        for provider in providers {
            if Task.isCancelled { return }
            switch await provider.fetch() {
            case .success(let snap):
                snapshots[provider.id] = snap
            case .failure:
                // A failed refresh must not present a previously-cached snapshot as
                // freshly refreshed — degrade this provider to unavailable instead.
                snapshots[provider.id] = nil
            }
        }
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
