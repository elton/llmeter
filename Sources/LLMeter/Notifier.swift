import Foundation
import UserNotifications
import LLMeterCore

enum Notifier {
    /// `UNUserNotificationCenter.current()` aborts the process unless it is hosted
    /// inside a real `.app` bundle (it needs a bundle identifier). When LLMeter is
    /// launched as a bare SPM executable (e.g. `swift run LLMeter` during development)
    /// there is no bundle identifier, so we skip notifications instead of crashing.
    private static var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    static func requestAuthorization() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func post(_ alerts: [QuotaAlert]) {
        guard isAvailable else { return }
        for alert in alerts {
            let content = UNMutableNotificationContent()
            content.title = L("notif.title", alert.provider.displayName, alert.windowLabel, Int(alert.percent))
            content.body = L("notif.body", alert.threshold)
            let request = UNNotificationRequest(identifier: "\(alert.id)-\(Int(alert.percent))",
                                                content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }
}
