import SwiftUI
import AppKit
import LLMeterCore

@main
struct LLMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    // Owned here, above PanelView's language `.id`, so switching language (which
    // rebuilds the panel subtree) doesn't reset which section is selected.
    @State private var selection: PanelSection = .overview

    var body: some Scene {
        // Single-icon mode: one combined gauge.
        MenuBarExtra(isInserted: .constant(isSingle)) {
            panel
        } label: {
            MenuBarLabel(status: delegate.store.status)
        }
        .menuBarExtraStyle(.window)

        // Multi-icon mode: one item per provider.
        MenuBarExtra(isInserted: .constant(isMulti)) {
            panel
        } label: {
            ProviderMenuBarLabel(provider: .codex, label: providerLabel(.codex))
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra(isInserted: .constant(isMulti)) {
            panel
        } label: {
            ProviderMenuBarLabel(provider: .claude, label: providerLabel(.claude))
        }
        .menuBarExtraStyle(.window)
    }

    private var panel: some View {
        PanelView(store: delegate.store, settings: delegate.settings,
                  codexStore: delegate.codexStore, login: delegate.login,
                  selection: $selection)
    }

    private var isSingle: Bool { delegate.settings.settings.displayMode == .singleIcon }
    private var isMulti: Bool { delegate.settings.settings.displayMode == .multiIcon }
    private func providerLabel(_ id: ProviderID) -> ProviderLabel? {
        delegate.store.status.providers.first { $0.provider == id }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings: SettingsModel
    let store: UsageStore
    let codexStore: CodexCredentialStore
    let login: CodexLoginService

    override init() {
        let settingsModel = SettingsModel(store: UserDefaultsSettingsStore())
        self.settings = settingsModel

        let credStore = CodexCredentialStore(keychain: SecAppKeychain())
        self.codexStore = credStore
        self.login = CodexLoginService(store: credStore,
                                       openURL: { url in DispatchQueue.main.async { _ = NSWorkspace.shared.open(url) } })

        let codexTokenProvider = CodexTokenProvider(store: credStore, http: URLSessionHTTPClient(), clock: SystemClock())
        self.store = UsageStore(
            providers: [CodexProvider(tokenProvider: codexTokenProvider), ClaudeProvider()],
            onAlerts: { alerts in
                if settingsModel.settings.notificationsEnabled { Notifier.post(alerts) }
            }
        )
        super.init()
        // Load the persisted language into Localizer before any L(...) runs. The
        // shared LocalizationManager is otherwise lazy, so a saved non-system
        // language wouldn't apply until the panel/settings first touched it.
        _ = LocalizationManager.shared
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // menu-bar agent, no Dock icon
        Notifier.requestAuthorization()
        store.startPolling(interval: { [settings] in settings.settings.pollIntervalSeconds })
    }
}
