import Foundation
import Observation

@MainActor
@Observable
public final class SettingsModel {
    public var settings: AppSettings {
        didSet { store.save(settings) }
    }

    @ObservationIgnored private let store: SettingsStore

    public init(store: SettingsStore) {
        self.store = store
        self.settings = store.load()
    }
}
