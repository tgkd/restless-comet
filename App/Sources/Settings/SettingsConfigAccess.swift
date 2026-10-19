import RestlessCore
import SwiftUI

enum SettingsConfigAccess {
    static func isEditable(_ store: ConfigStore) -> Bool {
        guard store.config != nil else {
            return false
        }
        if case .invalid = store.status {
            return false
        }
        return true
    }

    static func binding<Value>(
        _ model: AppModel,
        _ keyPath: WritableKeyPath<Config, Value>,
        fallback: Value
    ) -> Binding<Value> {
        Binding(
            get: { model.configStore.config?[keyPath: keyPath] ?? fallback },
            set: { newValue in
                model.updateConfig { config in
                    config[keyPath: keyPath] = newValue
                }
            }
        )
    }
}
