import SwiftUI
import AppKit
import LLMeterCore

@main
struct LLMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // Single-icon mode: one combined gauge.
        MenuBarExtra(isInserted: .constant(isSingle)) {
            PanelView(store: delegate.store, settings: delegate.settings)
        } label: {
            MenuBarLabel(status: delegate.store.status)
        }
        .menuBarExtraStyle(.window)

        // Multi-icon mode: one item per provider.
        MenuBarExtra(isInserted: .constant(isMulti)) {
            PanelView(store: delegate.store, settings: delegate.settings)
        } label: {
            ProviderMenuBarLabel(label: providerLabel(.codex))
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra(isInserted: .constant(isMulti)) {
            PanelView(store: delegate.store, settings: delegate.settings)
        } label: {
            ProviderMenuBarLabel(label: providerLabel(.claude))
        }
        .menuBarExtraStyle(.window)
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

    override init() {
        let settingsModel = SettingsModel(store: UserDefaultsSettingsStore())
        self.settings = settingsModel
        self.store = UsageStore(
            providers: [CodexProvider(), ClaudeProvider()],
            onAlerts: { alerts in
                if settingsModel.settings.notificationsEnabled { Notifier.post(alerts) }
            }
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // menu-bar agent, no Dock icon
        Notifier.requestAuthorization()
        store.startPolling(interval: { [settings] in settings.settings.pollIntervalSeconds })
    }
}
