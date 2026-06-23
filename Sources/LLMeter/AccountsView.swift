import SwiftUI
import LLMeterCore

struct AccountsView: View {
    let store: CodexCredentialStore
    let login: CodexLoginService

    @State private var tokens: CodexTokens?
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        Form {
            Section("Codex") {
                if let t = tokens {
                    LabeledContent(L("accounts.account"), value: t.accountId ?? "—")
                    LabeledContent(L("accounts.tokenExpires"), value: t.expiresAt.formatted(date: .abbreviated, time: .shortened))
                    Button(L("accounts.signOut")) { store.clear(); tokens = nil }
                } else {
                    Text(L("accounts.notSignedIn"))
                        .font(.callout).foregroundStyle(.secondary)
                }

                Button(tokens == nil ? L("accounts.signIn") : L("accounts.reauthenticate")) {
                    busy = true; error = nil
                    Task {
                        do { tokens = try await login.signIn() }
                        catch { self.error = error.localizedDescription }
                        busy = false
                    }
                }
                .disabled(busy)

                if busy { Text(L("accounts.waitingLogin")).font(.caption).foregroundStyle(.secondary) }
                if let error { Text(error).font(.caption).foregroundStyle(.red) }
            }

            Section("Claude") {
                Text(L("accounts.claudeLocal")).font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { tokens = store.load() }
    }
}
