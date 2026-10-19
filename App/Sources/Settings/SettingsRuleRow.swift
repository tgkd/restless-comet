import RestlessCore
import SwiftUI

struct SettingsRuleRow: View {
    let model: AppModel
    let rule: Rule
    let isEditable: Bool

    var body: some View {
        HStack(spacing: 10) {
            Toggle("Enabled", isOn: enabledBinding)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(!isEditable)
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name.isEmpty ? "Untitled rule" : rule.name)
                    .lineLimit(1)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private var summary: String {
        var conditions: [String] = []
        if !rule.domains.isEmpty {
            conditions.append(rule.domains.joined(separator: ", "))
        }
        if !rule.sourceApps.isEmpty {
            let names = rule.sourceApps.map { appName($0) }
            conditions.append("from " + names.joined(separator: ", "))
        }
        let condition = conditions.isEmpty ? "No conditions" : conditions.joined(separator: " · ")
        let target = rule.target.isEmpty ? "no browser" : appName(rule.target)
        return "\(condition) → \(target)"
    }

    private func appName(_ bundleID: String) -> String {
        SettingsAppDirectory.name(for: bundleID, browsers: model.installedBrowsers)
    }

    private var enabledBinding: Binding<Bool> {
        let ruleID = rule.id
        return Binding(
            get: { rule.enabled },
            set: { isEnabled in
                model.updateConfig { config in
                    if let index = config.rules.firstIndex(where: { $0.id == ruleID }) {
                        config.rules[index].enabled = isEnabled
                    }
                }
            }
        )
    }
}
