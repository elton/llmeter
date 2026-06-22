import Foundation

public struct CodexProvider: QuotaProvider {
    public let id: ProviderID = .codex

    private let http: HTTPClient
    private let clock: Clock
    private let authPath: URL
    private let sessionsDir: URL

    private static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    public init(http: HTTPClient = URLSessionHTTPClient(),
                clock: Clock = SystemClock(),
                authPath: URL = CodexCredentialsReader.defaultPath,
                sessionsDir: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex/sessions")) {
        self.http = http
        self.clock = clock
        self.authPath = authPath
        self.sessionsDir = sessionsDir
    }

    public func fetch() async -> Result<UsageSnapshot, ProviderError> {
        let live = await fetchLive()
        if case .success(let snap) = live { return .success(snap) }
        // Live failed — fall back to the most recent cached rollout if present.
        if let snap = fetchRolloutFallback() { return .success(snap) }
        // Nothing usable: surface why the live fetch failed.
        if case .failure(let error) = live { return .failure(error) }
        return .failure(.unavailable)
    }

    private func fetchLive() async -> Result<UsageSnapshot, ProviderError> {
        guard let creds = try? CodexCredentialsReader.read(authJSONPath: authPath) else {
            return .failure(.noCredentials)
        }
        let request = HTTPRequest(url: Self.usageURL, headers: [
            "Authorization": "Bearer \(creds.accessToken)",
            "chatgpt-account-id": creds.accountId,
            "Accept": "application/json",
        ])
        guard let (data, resp) = try? await http.get(request) else {
            return .failure(.network("request failed"))
        }
        guard resp.statusCode == 200 else {
            return .failure(.network("HTTP \(resp.statusCode)"))
        }
        do {
            return .success(try CodexUsageMapper.snapshot(from: data, capturedAt: clock.now, sourceLabel: "live"))
        } catch {
            return .failure(.decode("\(error)"))
        }
    }

    private func fetchRolloutFallback() -> UsageSnapshot? {
        // Try rollout files newest-first; return the first that yields a snapshot.
        for file in rolloutFilesNewestFirst(in: sessionsDir) {
            if let content = try? String(contentsOf: file, encoding: .utf8),
               let snap = CodexRolloutParser.snapshot(fromJSONL: content, capturedAt: clock.now) {
                return snap
            }
        }
        return nil
    }

    private func rolloutFilesNewestFirst(in dir: URL) -> [URL] {
        let fm = FileManager.default
        guard let en = fm.enumerator(at: dir,
                                     includingPropertiesForKeys: [.contentModificationDateKey],
                                     options: [.skipsHiddenFiles]) else { return [] }
        var files: [(url: URL, modified: Date)] = []
        for case let url as URL in en
            where url.pathExtension == "jsonl" && url.lastPathComponent.hasPrefix("rollout-") {
            let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            files.append((url, mod))
        }
        return files.sorted { $0.modified > $1.modified }.map(\.url)
    }
}
