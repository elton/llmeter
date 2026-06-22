import Foundation
import Network

public enum CodexLoginError: Error, Equatable { case timedOut }

/// Runs the Codex "Sign in with ChatGPT" PKCE flow: binds the loopback callback
/// server on a registered port (1455, then 1457) BEFORE opening the browser,
/// exchanges the code, and stores the tokens.
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
    public func signIn(timeoutSeconds: Double = 180) async throws -> CodexTokens {
        let verifier = PKCE.makeVerifier()
        let challenge = PKCE.challenge(forVerifier: verifier)
        let state = UUID().uuidString

        // Bind a registered port FIRST so the redirect target is live before the
        // browser opens, and so the fallback port can actually be used.
        let server = LoopbackServer(state: state)
        let port = try await server.bind(ports: [UInt16(CodexOAuth.defaultPort), UInt16(CodexOAuth.fallbackPort)])
        let redirect = CodexOAuth.redirectURI(port: Int(port))

        openURL(CodexOAuth.authorizeURL(redirectURI: redirect, codeChallenge: challenge, state: state))

        // Bounded wait: an abandoned/cancelled browser login times out and cleans up
        // the listener instead of hanging the Accounts view forever.
        let code = try await withThrowingTaskGroup(of: String.self) { group -> String in
            group.addTask { try await server.waitForCode() }
            group.addTask {
                try await Task.sleep(for: .seconds(timeoutSeconds))
                throw CodexLoginError.timedOut
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw CodexLoginError.timedOut }
            return first
        }
        let body = CodexOAuth.tokenExchangeBody(code: code, redirectURI: redirect, codeVerifier: verifier)
        let request = HTTPRequest(url: URL(string: "\(CodexOAuth.issuer)/oauth/token")!,
                                  headers: ["Content-Type": "application/x-www-form-urlencoded"])
        let (data, resp) = try await http.post(request, body: body)
        guard resp.statusCode == 200 else { throw CodexOAuthError.decode }
        let tokens = try CodexOAuth.parseTokenResponse(data, now: clock.now, requireCompleteGrant: true)
        store.save(tokens)
        return tokens
    }
}

/// One-shot loopback HTTP server: binds a registered port, then captures the OAuth
/// callback `code` (validating `state`).
final class LoopbackServer: @unchecked Sendable {
    private let state: String
    private let lock = NSLock()
    private var listener: NWListener?
    private var bindCont: CheckedContinuation<UInt16, Error>?
    private var codeCont: CheckedContinuation<String, Error>?
    private var pendingCode: Result<String, Error>?   // buffers a callback that arrives before waitForCode()

    init(state: String) { self.state = state }

    /// Binds the first port that becomes `.ready`; returns it. Throws if none bind.
    func bind(ports: [UInt16]) async throws -> UInt16 {
        var lastError: Error = NSError(domain: "login", code: 9,
                                       userInfo: [NSLocalizedDescriptionKey: "no ports to bind"])
        for port in ports {
            do { return try await bindOne(port) } catch { lastError = error }
        }
        throw lastError
    }

    private func bindOne(_ port: UInt16) async throws -> UInt16 {
        try await withCheckedThrowingContinuation { cont in
            lock.lock(); bindCont = cont; lock.unlock()
            do {
                let l = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
                listener = l
                l.stateUpdateHandler = { [weak self] st in
                    guard let self else { return }
                    switch st {
                    case .ready:
                        self.resumeBind(.success(port))
                    case .failed(let err):
                        // A failure before this port has bound is a bind failure (try the
                        // next port); only a failure AFTER binding fails the code wait.
                        if !self.resumeBind(.failure(err)) { self.resumeCode(.failure(err)) }
                    case .waiting(let err):
                        // A busy port (EADDRINUSE) makes NWListener wait/retry rather than
                        // fail — treat it as a bind failure so we move to the fallback port.
                        self.resumeBind(.failure(err))
                    default:
                        break
                    }
                }
                l.newConnectionHandler = { [weak self] conn in self?.handle(conn) }
                l.start(queue: DispatchQueue(label: "llmeter.login.\(port)"))
            } catch {
                resumeBind(.failure(error))
            }
        }
    }

    func waitForCode() async throws -> String {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { cont in
                lock.lock()
                if let buffered = pendingCode {
                    pendingCode = nil
                    lock.unlock()
                    switch buffered {
                    case .success(let s): cont.resume(returning: s)
                    case .failure(let e): cont.resume(throwing: e)
                    }
                } else {
                    codeCont = cont
                    lock.unlock()
                }
            }
        } onCancel: {
            resumeCode(.failure(CancellationError()))
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
            resumeCode(.failure(NSError(domain: "login", code: 1,
                                        userInfo: [NSLocalizedDescriptionKey: "invalid callback or state mismatch"])))
            return
        }
        resumeCode(.success(code))
    }

    /// Resumes the in-flight bind continuation, if any. Returns true when it
    /// consumed one (i.e. this was the bind phase), false when already bound.
    @discardableResult
    private func resumeBind(_ result: Result<UInt16, Error>) -> Bool {
        lock.lock(); let c = bindCont; bindCont = nil; lock.unlock()
        guard let c else { return false }
        if case .failure = result { listener?.cancel() }
        switch result {
        case .success(let p): c.resume(returning: p)
        case .failure(let e): c.resume(throwing: e)
        }
        return true
    }

    private func resumeCode(_ result: Result<String, Error>) {
        lock.lock()
        let c = codeCont
        codeCont = nil
        if c == nil, pendingCode == nil { pendingCode = result }   // buffer until waitForCode() installs a waiter
        lock.unlock()
        listener?.cancel()
        guard let c else { return }
        switch result {
        case .success(let s): c.resume(returning: s)
        case .failure(let e): c.resume(throwing: e)
        }
    }
}
