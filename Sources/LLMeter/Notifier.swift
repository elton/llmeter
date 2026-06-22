import UserNotifications
import LLMeterCore

enum Notifier {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func post(_ alerts: [QuotaAlert]) {
        for alert in alerts {
            let content = UNMutableNotificationContent()
            content.title = "\(alert.provider.displayName) \(alert.windowLabel) at \(Int(alert.percent))%"
            content.body = "You've crossed \(alert.threshold)% of this window."
            let request = UNNotificationRequest(identifier: "\(alert.id)-\(Int(alert.percent))",
                                                content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }
}
