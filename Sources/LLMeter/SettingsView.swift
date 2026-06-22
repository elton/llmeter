import SwiftUI
import AppKit
import LLMeterCore

struct SettingsView: View {
    @Bindable var model: SettingsModel
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    private let intervals = [60, 120, 300, 600, 1800]

    var body: some View {
        Form {
            Picker("Menu bar", selection: $model.settings.displayMode) {
                Text("Single icon").tag(DisplayMode.singleIcon)
                Text("One per provider").tag(DisplayMode.multiIcon)
            }

            Picker("Refresh every", selection: $model.settings.pollIntervalSeconds) {
                ForEach(intervals, id: \.self) { secs in
                    Text(secs < 60 ? "\(secs)s" : "\(secs / 60)m").tag(secs)
                }
            }

            Toggle("Notify at 70% / 90%", isOn: $model.settings.notificationsEnabled)

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    if !LaunchAtLogin.set(newValue) { launchAtLogin = LaunchAtLogin.isEnabled }
                }

            Divider()
            Button("Quit LLMeter") { NSApplication.shared.terminate(nil) }
        }
        .formStyle(.grouped)
        .padding(4)
    }
}
