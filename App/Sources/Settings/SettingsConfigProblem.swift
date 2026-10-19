import RestlessCore

struct SettingsConfigProblem: Equatable {
    let title: String
    let details: [String]
    let consequences: [String]

    init?(store: ConfigStore) {
        let hasConfig = store.config != nil
        switch store.status {
        case .invalid(.unreadable(let message)):
            title = "The settings file can't be read."
            details = [message]
        case .invalid(.unsupportedSchema(let version)):
            title = "The settings file uses an unsupported schema version."
            details = [
                "It has schemaVersion \(version), and this version of Restless Comet reads schemaVersion \(Config.currentSchemaVersion)."
            ]
        case .invalid(.invalid(let messages)):
            title = "The settings file has errors."
            details = messages
        case .missing, .loaded:
            if hasConfig {
                return nil
            }
            title = "Settings aren't loaded."
            details = []
        }
        var consequences: [String] = []
        if !hasConfig {
            consequences.append("Links will show the picker until the file is fixed.")
        }
        consequences.append("Changes are disabled until the file is fixed.")
        self.consequences = consequences
    }
}
