import AppKit
import RestlessCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsRuleEditor: View {
    let model: AppModel
    let isNew: Bool
    let onSave: (Rule.ID) -> Void

    @State private var draft: Rule
    @State private var domainsText: String
    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, rule: Rule, isNew: Bool, onSave: @escaping (Rule.ID) -> Void) {
        self.model = model
        self.isNew = isNew
        self.onSave = onSave
        var initial = rule
        initial.sourceApps = SettingsDeduplication.unique(rule.sourceApps)
        _draft = State(initialValue: initial)
        _domainsText = State(initialValue: rule.domains.joined(separator: ", "))
    }

    private var entries: [SettingsDomainEntry] {
        SettingsDomainEntry.parse(domainsText)
    }

    private var canSave: Bool {
        guard SettingsConfigAccess.isEditable(model.configStore) else {
            return false
        }
        guard !draft.target.isEmpty, draft.target != model.selfBundleID else {
            return false
        }
        let entries = self.entries
        guard entries.allSatisfy({ $0.host != nil }) else {
            return false
        }
        return !entries.isEmpty || !draft.sourceApps.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                SettingsErrorBanner(model: model)
                generalSection
                domainsSection
                sourceAppsSection
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(16)
        }
        .frame(width: SettingsMetrics.editorWidth)
    }

    private var generalSection: some View {
        Section {
            TextField("Name", text: $draft.name, prompt: Text("Untitled rule"))
            Picker("Open in", selection: $draft.target) {
                targetOptions
            }
            Toggle("Enabled", isOn: $draft.enabled)
        } header: {
            Text(isNew ? "New Rule" : "Edit Rule")
        }
    }

    @ViewBuilder
    private var targetOptions: some View {
        if draft.target.isEmpty {
            Text("Choose a Browser")
                .tag("")
            Divider()
        }
        ForEach(model.installedBrowsers) { browser in
            SettingsBrowserLabel(browser: browser)
                .tag(browser.bundleID)
        }
        if !draft.target.isEmpty, !model.installedBrowsers.contains(where: { $0.bundleID == draft.target }) {
            SettingsBrowserLabel(missingBundleID: draft.target)
                .tag(draft.target)
        }
    }

    private var domainsSection: some View {
        Section {
            TextField("Domains", text: $domainsText, prompt: Text("example.com, https://example.org/page"), axis: .vertical)
                .labelsHidden()
                .lineLimit(1...4)
            ForEach(entries) { entry in
                domainFeedback(entry)
            }
        } header: {
            Text("Domains")
        } footer: {
            Text("Separate entries with commas. A pasted URL is reduced to its host, and a domain also matches its subdomains.")
        }
    }

    @ViewBuilder
    private func domainFeedback(_ entry: SettingsDomainEntry) -> some View {
        if let host = entry.host {
            LabeledContent {
                if host != entry.input {
                    Text(entry.input)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } label: {
                Label {
                    Text(host)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        } else {
            LabeledContent {
                Text("Not a valid domain or URL")
                    .foregroundStyle(.red)
            } label: {
                Label {
                    Text(entry.input)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } icon: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var sourceAppsSection: some View {
        Section {
            if draft.sourceApps.isEmpty {
                LabeledContent {
                    addSourceAppsButton
                } label: {
                    Text("Any app")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(draft.sourceApps, id: \.self) { bundleID in
                    sourceAppRow(bundleID)
                }
                HStack {
                    Spacer()
                    addSourceAppsButton
                }
            }
        } header: {
            Text("Source Apps")
        } footer: {
            Text("The link must also have been clicked in one of these apps.")
        }
    }

    private var addSourceAppsButton: some View {
        Button("Add App…") {
            chooseSourceApps()
        }
    }

    private func sourceAppRow(_ bundleID: String) -> some View {
        let name = SettingsAppDirectory.name(for: bundleID, browsers: model.installedBrowsers)
        return HStack(spacing: 8) {
            Image(nsImage: SettingsAppDirectory.smallIcon(for: bundleID))
            Text(name)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button {
                draft.sourceApps.removeAll { $0 == bundleID }
            } label: {
                Label("Remove \(name)", systemImage: "minus.circle.fill")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Remove \(name)")
        }
    }

    private func chooseSourceApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(filePath: "/Applications", directoryHint: .isDirectory)
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Add"
        panel.message = "Choose the apps a link must be clicked in."
        guard panel.runModal() == .OK else {
            return
        }
        for url in panel.urls {
            guard let bundleID = Bundle(url: url)?.bundleIdentifier, !draft.sourceApps.contains(bundleID) else {
                continue
            }
            draft.sourceApps.append(bundleID)
        }
    }

    private func save() {
        guard canSave else {
            return
        }
        var rule = draft
        rule.name = rule.name.trimmingCharacters(in: .whitespacesAndNewlines)
        rule.domains = SettingsDomainEntry.uniqueHosts(in: entries)
        let savedRule = rule
        model.lastError = nil
        model.updateConfig { config in
            if let index = config.rules.firstIndex(where: { $0.id == savedRule.id }) {
                config.rules[index] = savedRule
            } else {
                config.rules.append(savedRule)
            }
        }
        guard model.lastError == nil else {
            return
        }
        onSave(savedRule.id)
        dismiss()
    }
}
