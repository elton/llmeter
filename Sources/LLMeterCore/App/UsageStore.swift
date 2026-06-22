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

    public func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        for provider in providers {
            if case .success(let snap) = await provider.fetch() {
                snapshots[provider.id] = snap
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
