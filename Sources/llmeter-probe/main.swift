import Foundation
import LLMeterCore

func line(_ w: UsageWindow) -> String {
    let label = w.label.padding(toLength: 8, withPad: " ", startingAt: 0)
    if let pct = w.percent {
        let reset = w.resetsAt.map { " · resets " + relative($0) } ?? ""
        return "  \(label) \(Int(pct))%\(reset)"
    } else {
        let cost = w.estimatedCostUSD.map { String(format: " · ~$%.2f", $0) } ?? ""
        return "  \(label) \(w.usedTokens ?? 0) tok\(cost)"
    }
}

func relative(_ date: Date) -> String {
    let secs = Int(date.timeIntervalSinceNow)
    if secs <= 0 { return "now" }
    let h = secs / 3600, m = (secs % 3600) / 60
    return h > 0 ? "in \(h)h \(m)m" : "in \(m)m"
}

func printSnapshot(_ label: String, _ result: Result<UsageSnapshot, ProviderError>) {
    switch result {
    case .success(let snap):
        let plan = snap.planType.map { " (\($0))" } ?? ""
        let source = snap.isStale ? " [\(snap.sourceLabel), stale]" : " [\(snap.sourceLabel)]"
        print("\(label)\(plan)\(source)")
        for w in snap.windows { print(line(w)) }
        if let credits = snap.creditsBalance { print("  credits: \(credits)") }
    case .failure(let error):
        print("\(label): unavailable (\(error))")
    }
    print("")
}

// Probe is a headless diagnostic; it reads the Codex CLI login only (the app-OAuth
// token lives in the app's keychain and is read in-process by LLMeter.app).
let codex = await CodexProvider().fetch()
let claude = await ClaudeProvider().fetch()
printSnapshot("CODEX", codex)
printSnapshot("CLAUDE", claude)
