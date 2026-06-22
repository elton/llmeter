import SwiftUI
import AppKit
import LLMeterCore

@main
struct LLMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: delegate.store)
        } label: {
            MenuBarLabel(status: delegate.store.status)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = UsageStore(providers: [CodexProvider(), ClaudeProvider()])

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // menu-bar agent, no Dock icon
        store.startPolling(everySeconds: 300)
    }
}
