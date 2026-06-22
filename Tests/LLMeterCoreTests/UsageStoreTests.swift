import Testing
import Foundation
@testable import LLMeterCore

@MainActor
struct UsageStoreTests {
    private let now = Date(timeIntervalSince1970: 1_782_000_000)

    @Test func refreshStoresSuccessesAndSkipsFailures() async {
        let codex = UsageSnapshot(provider: .codex,
                                  windows: [UsageWindow(kind: .fiveHour, label: "5h", percent: 77)],
                                  capturedAt: now, sourceLabel: "live")
        let store = UsageStore(providers: [
            StubProvider(id: .codex, result: .success(codex)),
            StubProvider(id: .claude, result: .failure(.unavailable)),
        ])

        #expect(store.lastRefresh == nil)
        await store.refresh()

        #expect(store.snapshots[.codex]?.windows.first?.percent == 77)
        #expect(store.snapshots[.claude] == nil)          // failed fetch → not stored
        #expect(store.status.overall == .warning)
        #expect(store.lastRefresh != nil)
        #expect(store.isRefreshing == false)
    }

    @Test func failedRefreshClearsPreviouslySuccessfulSnapshot() async {
        let codex = UsageSnapshot(provider: .codex,
                                  windows: [UsageWindow(kind: .fiveHour, label: "5h", percent: 50)],
                                  capturedAt: now, sourceLabel: "live")
        let provider = SequenceProvider(id: .codex, results: [.success(codex), .failure(.network("down"))])
        let store = UsageStore(providers: [provider])

        await store.refresh()
        #expect(store.snapshots[.codex] != nil)        // first refresh succeeded

        await store.refresh()
        #expect(store.snapshots[.codex] == nil)        // failed refresh degraded it to unavailable
        #expect(store.status.providers.first { $0.provider == .codex }?.text == "—")
    }
}

