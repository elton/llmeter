import SwiftUI
import AppKit
import LLMeterCore

struct SettingsView: View {
    @Bindable var model: SettingsModel
    @Bindable private var localization = LocalizationManager.shared
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    private let intervals = [60, 120, 300, 600, 1800]

    var body: some View {
        Form {
            Picker(L("settings.menuBar"), selection: $model.settings.displayMode) {
                Text(L("settings.singleIcon")).tag(DisplayMode.singleIcon)
                Text(L("settings.onePerProvider")).tag(DisplayMode.multiIcon)
            }

            Picker(L("settings.language"), selection: $localization.language) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Text(lang == .system ? L("language.system") : lang.endonym).tag(lang)
                }
            }

            Picker(L("settings.refreshEvery"), selection: $model.settings.pollIntervalSeconds) {
                ForEach(intervals, id: \.self) { secs in
                    Text(secs < 60 ? "\(secs)s" : "\(secs / 60)m").tag(secs)
                }
            }

            Toggle(L("settings.notify"), isOn: $model.settings.notificationsEnabled)

            Toggle(L("settings.launchAtLogin"), isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    if !LaunchAtLogin.set(newValue) { launchAtLogin = LaunchAtLogin.isEnabled }
                }

            Divider()
            Button(L("settings.quit")) { NSApplication.shared.terminate(nil) }
        }
        .formStyle(.grouped)
        .padding(4)
    }
}
