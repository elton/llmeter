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

    @Test func overlappingRefreshesRunAtMostOneSweep() async {
        let snap = UsageSnapshot(provider: .codex,
                                 windows: [UsageWindow(kind: .fiveHour, label: "5h", percent: 30)],
                                 capturedAt: now, sourceLabel: "live")
        let provider = CountingProvider(id: .codex, snapshot: snap, delaySeconds: 0.1)
        let store = UsageStore(providers: [provider])

        async let first: Void = store.refresh()
        async let second: Void = store.refresh()
        _ = await first
        _ = await second

        #expect(await provider.fetchCount == 1)        // concurrent caller skipped the in-flight sweep
        #expect(store.snapshots[.codex]?.windows.first?.percent == 30)
    }

    @Test func fastProviderPublishesWithoutWaitingForSlowOne() async {
        let fast = UsageSnapshot(provider: .claude,
                                 windows: [UsageWindow(kind: .rolling, label: "7d", percent: nil, usedTokens: 500)],
                                 capturedAt: now, sourceLabel: "local logs")
        let slow = UsageSnapshot(provider: .codex,
                                 windows: [UsageWindow(kind: .fiveHour, label: "5h", percent: 20)],
                                 capturedAt: now, sourceLabel: "live")
        let store = UsageStore(providers: [
            CountingProvider(id: .claude, snapshot: fast, delaySeconds: 0.0),
            CountingProvider(id: .codex, snapshot: slow, delaySeconds: 0.5),
        ])

        let task = Task { await store.refresh() }
        try? await Task.sleep(nanoseconds: 150_000_000)        // fast done, slow still running
        #expect(store.snapshots[.claude] != nil)               // fast published already
        #expect(store.snapshots[.codex] == nil)                // slow not blocking it, not yet published

        await task.value
        #expect(store.snapshots[.codex] != nil)                // slow eventually published
    }

    @Test func cancelledRefreshKeepsLastGoodSnapshot() async {
        let good = UsageSnapshot(provider: .codex,
                                 windows: [UsageWindow(kind: .fiveHour, label: "5h", percent: 40)],
                                 capturedAt: now, sourceLabel: "live")
        let store = UsageStore(providers: [SucceedThenHangProvider(id: .codex, snapshot: good)])

        await store.refresh()                                  // seeds the good snapshot
        #expect(store.snapshots[.codex]?.windows.first?.percent == 40)

        let task = Task { await store.refresh() }              // second sweep hangs in fetch
        try? await Task.sleep(nanoseconds: 100_000_000)        // let it enter the hang
        task.cancel()
        await task.value
        #expect(store.snapshots[.codex]?.windows.first?.percent == 40)  // preserved, not cleared
    }

    @Test func refreshEmitsRisingThresholdAlerts() async {
        func snap(_ pct: Double) -> UsageSnapshot {
            UsageSnapshot(provider: .codex, windows: [UsageWindow(kind: .fiveHour, label: "5h", percent: pct)],
                          capturedAt: now, sourceLabel: "live")
        }
        var received: [QuotaAlert] = []
        let provider = SequenceProvider(id: .codex, results: [.success(snap(60)), .success(snap(75))])
        let store = UsageStore(providers: [provider], onAlerts: { received.append(contentsOf: $0) })

        await store.refresh()   // 60% — no crossing
        await store.refresh()   // 75% — crosses 70
        #expect(received.map(\.threshold) == [70])
    }

    @Test func pollingRepeatsWithDynamicInterval() async {
        let snap = UsageSnapshot(provider: .codex,
                                 windows: [UsageWindow(kind: .fiveHour, label: "5h", percent: 10)],
                                 capturedAt: now, sourceLabel: "live")
        let provider = CountingProvider(id: .codex, snapshot: snap, delaySeconds: 0.0)
        let store = UsageStore(providers: [provider])

        store.startPolling(interval: { 1 })
        try? await Task.sleep(nanoseconds: 1_300_000_000)   // ~2 cycles at 1s
        store.stopPolling()

        #expect(await provider.fetchCount >= 2)
    }

    @Test func recoveryAfterFailureDoesNotRefireThreshold() async {
        func snap(_ pct: Double) -> UsageSnapshot {
            UsageSnapshot(provider: .codex, windows: [UsageWindow(kind: .fiveHour, label: "5h", percent: pct)],
                          capturedAt: now, sourceLabel: "live")
        }
        var received: [QuotaAlert] = []
        let provider = SequenceProvider(id: .codex,
                                        results: [.success(snap(95)), .failure(.network("down")), .success(snap(96))])
        let store = UsageStore(providers: [provider], onAlerts: { received.append(contentsOf: $0) })

        await store.refresh()   // 95 — crosses 70 & 90 from baseline 0
        await store.refresh()   // fails — display cleared, alert baseline keeps 95
        await store.refresh()   // 96 — baseline 95, no new crossing

        #expect(received.map(\.threshold) == [70, 90])   // not re-fired on recovery
    }
}

