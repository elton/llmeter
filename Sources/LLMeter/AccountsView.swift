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
                    LabeledContent("Account", value: t.accountId ?? "—")
                    LabeledContent("Token expires", value: t.expiresAt.formatted(date: .abbreviated, time: .shortened))
                    Button("Sign out") { store.clear(); tokens = nil }
                } else {
                    Text("Not signed in — uses the Codex CLI login if present.")
                        .font(.callout).foregroundStyle(.secondary)
                }

                Button(tokens == nil ? "Sign in with ChatGPT" : "Re-authenticate") {
                    busy = true; error = nil
                    Task {
                        do { tokens = try await login.signIn() }
                        catch { self.error = error.localizedDescription }
                        busy = false
                    }
                }
                .disabled(busy)

                if busy { Text("Waiting for browser login…").font(.caption).foregroundStyle(.secondary) }
                if let error { Text(error).font(.caption).foregroundStyle(.red) }
            }

            Section("Claude") {
                Text("Local logs — no sign-in needed.").font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { tokens = store.load() }
    }
}
