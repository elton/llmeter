import Foundation
import AppKit
import LLMeterCore

let service = CodexLoginService(
    store: CodexCredentialStore(keychain: SecAppKeychain()),
    openURL: { url in NSWorkspace.shared.open(url) }
)

print("Opening browser for ChatGPT login (port \(CodexOAuth.defaultPort))…")
do {
    let tokens = try await service.signIn()
    print("Login OK — stored Codex tokens in app keychain. account=\(tokens.accountId ?? "?"), expires \(tokens.expiresAt)")
} catch {
    print("Login error: \(error.localizedDescription)")
    exit(1)
}
