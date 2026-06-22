import Foundation
import Network

/// Runs the Codex "Sign in with ChatGPT" PKCE flow: opens the browser, captures the
/// loopback callback on port 1455, exchanges the code, and stores the tokens.
public struct CodexLoginService: Sendable {
    private let store: CodexCredentialStore
    private let http: HTTPClient
    private let clock: Clock
    private let openURL: @Sendable (URL) -> Void

    public init(store: CodexCredentialStore, http: HTTPClient = URLSessionHTTPClient(),
                clock: Clock = SystemClock(), openURL: @escaping @Sendable (URL) -> Void) {
        self.store = store
        self.http = http
        self.clock = clock
        self.openURL = openURL
    }

    @discardableResult
    public func signIn() async throws -> CodexTokens {
        let verifier = PKCE.makeVerifier()
        let challenge = PKCE.challenge(forVerifier: verifier)
        let state = UUID().uuidString
        let port = CodexOAuth.defaultPort
        let redirect = CodexOAuth.redirectURI(port: port)

        openURL(CodexOAuth.authorizeURL(redirectURI: redirect, codeChallenge: challenge, state: state))

        let code = try await LoopbackServer(state: state).waitForCode(port: UInt16(port))
        let body = CodexOAuth.tokenExchangeBody(code: code, redirectURI: redirect, codeVerifier: verifier)
        let request = HTTPRequest(url: URL(string: "\(CodexOAuth.issuer)/oauth/token")!,
                                  headers: ["Content-Type": "application/x-www-form-urlencoded"])
        let (data, resp) = try await http.post(request, body: body)
        guard resp.statusCode == 200 else { throw CodexOAuthError.decode }
        let tokens = try CodexOAuth.parseTokenResponse(data, now: clock.now)
        store.save(tokens)
        return tokens
    }
}

/// Minimal one-shot loopback HTTP server that captures the OAuth callback `code`,
/// validating `state`.
final class LoopbackServer: @unchecked Sendable {
    private let state: String
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String, Error>?
    private var listener: NWListener?

    init(state: String) { self.state = state }

    func waitForCode(port: UInt16) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            lock.lock(); continuation = cont; lock.unlock()
            do {
                let l = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
                listener = l
                l.stateUpdateHandler = { [weak self] st in
                    if case .failed(let err) = st { self?.resume(.failure(err)) }
                }
                l.newConnectionHandler = { [weak self] conn in self?.handle(conn) }
                l.start(queue: DispatchQueue(label: "llmeter.login"))
            } catch {
                resume(.failure(error))
            }
        }
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: DispatchQueue(label: "llmeter.login.conn"))
        conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let self else { return }
            let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let path = request.split(separator: " ").dropFirst().first.map(String.init) ?? ""
            let body = "<h2>LLMeter: login received \u{2713} — you can close this tab.</h2>"
            let resp = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
            conn.send(content: Data(resp.utf8), completion: .contentProcessed { _ in conn.cancel() })
            self.finish(path: path)
        }
    }

    private func finish(path: String) {
        guard let comps = URLComponents(string: "http://localhost\(path)"),
              let code = comps.queryItems?.first(where: { $0.name == "code" })?.value,
              comps.queryItems?.first(where: { $0.name == "state" })?.value == state else {
            resume(.failure(NSError(domain: "login", code: 1,
                                    userInfo: [NSLocalizedDescriptionKey: "invalid callback or state mismatch"])))
            return
        }
        resume(.success(code))
    }

    private func resume(_ result: Result<String, Error>) {
        lock.lock(); let c = continuation; continuation = nil; lock.unlock()
        guard let c else { return }
        listener?.cancel()
        switch result {
        case .success(let s): c.resume(returning: s)
        case .failure(let e): c.resume(throwing: e)
        }
    }
}
