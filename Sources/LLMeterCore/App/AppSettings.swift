import Foundation

public enum DisplayMode: String, Sendable, CaseIterable, Codable {
    case singleIcon
    case multiIcon
}

public struct AppSettings: Equatable, Sendable, Codable {
    public var displayMode: DisplayMode
    public var pollIntervalSeconds: Int
    public var notificationsEnabled: Bool

    public init(displayMode: DisplayMode = .singleIcon,
                pollIntervalSeconds: Int = 300,
                notificationsEnabled: Bool = true) {
        self.displayMode = displayMode
        self.pollIntervalSeconds = pollIntervalSeconds
        self.notificationsEnabled = notificationsEnabled
    }
}

public protocol SettingsStore: Sendable {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
}

public final class UserDefaultsSettingsStore: SettingsStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "llmeter.settings"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return settings
    }

    public func save(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: key)
        }
    }
}
