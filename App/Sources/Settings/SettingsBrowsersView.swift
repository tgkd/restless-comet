import RestlessCore
import SwiftUI

struct SettingsBrowsersView: View {
    let model: AppModel

    private var isEditable: Bool {
        SettingsConfigAccess.isEditable(model.configStore)
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
                Picker(selection: SettingsConfigAccess.binding(model, \.defaultBrowser, fallback: nil)) {
                    Text("Prompt")
                        .tag(String?.none)
                    Divider()
                    browserOptions(selected: model.configStore.config?.defaultBrowser)
                } label: {
                    Text("Open links in")
                    Text("Used when no rule matches. Prompt shows the picker.")
                }
                Picker(selection: SettingsConfigAccess.binding(model, \.alternativeBrowser, fallback: nil)) {
                    Text("None")
                        .tag(String?.none)
                    Divider()
                    browserOptions(selected: model.configStore.config?.alternativeBrowser)
                } label: {
                    Text("Alternative browser")
                    Text("Hold Fn while clicking a link to open it here.")
                }
            }
            .disabled(!isEditable)
            SettingsShownBrowsersSection(model: model)
                .disabled(!isEditable)
        }
        .formStyle(.grouped)
        .frame(width: SettingsMetrics.windowWidth)
    }

    @ViewBuilder
    private func browserOptions(selected: String?) -> some View {
        ForEach(model.installedBrowsers) { browser in
            SettingsBrowserLabel(browser: browser)
                .tag(String?.some(browser.bundleID))
        }
        if let selected, !model.installedBrowsers.contains(where: { $0.bundleID == selected }) {
            SettingsBrowserLabel(missingBundleID: selected)
                .tag(String?.some(selected))
        }
    }
}
