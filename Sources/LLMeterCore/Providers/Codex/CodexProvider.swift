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
        if let snap = await fetchLive() { return .success(snap) }
        if let snap = fetchRolloutFallback() { return .success(snap) }
        return .failure(.unavailable)
    }

    private func fetchLive() async -> UsageSnapshot? {
        guard let creds = try? CodexCredentialsReader.read(authJSONPath: authPath) else { return nil }
        let request = HTTPRequest(url: Self.usageURL, headers: [
            "Authorization": "Bearer \(creds.accessToken)",
            "chatgpt-account-id": creds.accountId,
            "Accept": "application/json",
        ])
        guard let (data, resp) = try? await http.get(request), resp.statusCode == 200 else { return nil }
        return try? CodexUsageMapper.snapshot(from: data, capturedAt: clock.now, sourceLabel: "live")
    }

    private func fetchRolloutFallback() -> UsageSnapshot? {
        guard let file = newestJSONL(in: sessionsDir),
              let content = try? String(contentsOf: file, encoding: .utf8) else { return nil }
        return CodexRolloutParser.snapshot(fromJSONL: content, capturedAt: clock.now)
    }

    private func newestJSONL(in dir: URL) -> URL? {
        let fm = FileManager.default
        guard let en = fm.enumerator(at: dir,
                                     includingPropertiesForKeys: [.contentModificationDateKey],
                                     options: [.skipsHiddenFiles]) else { return nil }
        var newest: (URL, Date)?
        for case let url as URL in en where url.pathExtension == "jsonl" {
            let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if newest == nil || mod > newest!.1 { newest = (url, mod) }
        }
        return newest?.0
    }
}
