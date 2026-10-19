import RestlessCore
import SwiftUI

struct SettingsRuleEditing: Identifiable {
    let rule: Rule
    let isNew: Bool

    var id: Rule.ID {
        rule.id
    }
}

struct SettingsRulesView: View {
    let model: AppModel

    @State private var selection: Rule.ID?
    @State private var editing: SettingsRuleEditing?

    private var rules: [Rule] {
        model.configStore.config?.rules ?? []
    }

    private var isEditable: Bool {
        SettingsConfigAccess.isEditable(model.configStore)
    }

    private var selectedRule: Rule? {
        guard let selection else {
            return nil
        }
        return rules.first { $0.id == selection }
    }

    var body: some View {
        Form {
            SettingsErrorBanner(model: model)
            if let problem = SettingsConfigProblem(store: model.configStore) {
                Section {
                    SettingsConfigProblemView(problem: problem)
                }
            }
            Section {
                rulesList
                actionBar
            } header: {
                Text("Rules")
            } footer: {
                Text("From top to bottom, the first enabled rule that matches a link picks its browser. Links that match no rule use the default browser, and holding Fn uses the alternative browser instead.")
            }
        }
        .formStyle(.grouped)
        .frame(width: SettingsMetrics.windowWidth)
        .sheet(item: $editing) { editing in
            SettingsRuleEditor(model: model, rule: editing.rule, isNew: editing.isNew) { savedID in
                selection = savedID
            }
        }
    }

    private var rulesList: some View {
        List(selection: $selection) {
            ForEach(rules) { rule in
                SettingsRuleRow(model: model, rule: rule, isEditable: isEditable)
                    .moveDisabled(!isEditable)
            }
            .onMove { source, destination in
                moveRules(from: source, to: destination)
            }
        }
        .scrollContentBackground(.hidden)
        .contextMenu(forSelectionType: Rule.ID.self) { ids in
            if let id = ids.first, ids.count == 1 {
                Button("Edit…") {
                    edit(id)
                }
                .disabled(!isEditable)
                Button("Delete", role: .destructive) {
                    delete(id)
                }
                .disabled(!isEditable)
            }
        } primaryAction: { ids in
            if let id = ids.first, ids.count == 1 {
                edit(id)
            }
        }
        .onDeleteCommand {
            deleteSelectedRule()
        }
        .overlay {
            if rules.isEmpty {
                ContentUnavailableView {
                    Label("No Rules", systemImage: "arrow.triangle.branch")
                } description: {
                    Text("Add a rule to open matching links in a specific browser.")
                }
            }
        }
        .frame(height: SettingsMetrics.rulesListHeight)
    }

    private var actionBar: some View {
        HStack(spacing: 4) {
            Button {
                addRule()
            } label: {
                Label("Add Rule", systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Add a rule")
            Button {
                deleteSelectedRule()
            } label: {
                Label("Delete Rule", systemImage: "minus")
                    .labelStyle(.iconOnly)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Delete the selected rule")
            .disabled(selectedRule == nil)
            Spacer()
            Button("Edit…") {
                if let selectedRule {
                    edit(selectedRule.id)
                }
            }
            .disabled(selectedRule == nil)
        }
        .disabled(!isEditable)
    }

    private func addRule() {
        guard isEditable else {
            return
        }
        editing = SettingsRuleEditing(rule: Rule(name: "", target: ""), isNew: true)
    }

    private func edit(_ id: Rule.ID) {
        guard isEditable, let rule = rules.first(where: { $0.id == id }) else {
            return
        }
        selection = id
        editing = SettingsRuleEditing(rule: rule, isNew: false)
    }

    private func deleteSelectedRule() {
        guard let selectedRule else {
            return
        }
        delete(selectedRule.id)
    }

    private func delete(_ id: Rule.ID) {
        guard isEditable else {
            return
        }
        model.updateConfig { config in
            config.rules.removeAll { $0.id == id }
        }
        if selection == id {
            selection = nil
        }
    }

    private func moveRules(from source: IndexSet, to destination: Int) {
        guard isEditable else {
            return
        }
        model.updateConfig { config in
            config.rules.move(fromOffsets: source, toOffset: destination)
        }
    }
}
