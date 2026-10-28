import AppKit
import RestlessCore
import ServiceManagement
import SwiftUI

struct SettingsGeneralView: View {
    let model: AppModel

    var body: some View {
        Form {
            SettingsErrorBanner(model: model)
            defaultBrowserSection
            launchAtLoginSection
            menuBarSection
            settingsFileSection
            diagnosticsSection
            quitSection
        }
        .formStyle(.grouped)
        .frame(width: SettingsMetrics.windowWidth)
    }

    private var defaultBrowserSection: some View {
        Section {
            LabeledContent {
                Button("Make Default…") {
                    Task {
                        await model.makeDefaultBrowser()
                    }
                }
                .disabled(!canMakeDefault)
            } label: {
                Label {
                    Text(SettingsStatusText.defaultBrowser(model.defaultBrowserStatus))
                } icon: {
                    defaultBrowserStatusIcon
                }
            }
        } header: {
            Text("Default Browser")
        } footer: {
            Text("Restless Comet can route links only while it is the default browser.")
        }
    }

    private var canMakeDefault: Bool {
        model.canMakeDefault && model.defaultBrowserStatus != .isDefault
    }

    @ViewBuilder
    private var defaultBrowserStatusIcon: some View {
        switch model.defaultBrowserStatus {
        case .isDefault:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .partial, .notDefault:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        case .unknown:
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
    }

    private var launchAtLoginSection: some View {
        Section {
            Toggle(isOn: launchAtLoginBinding) {
                Text("Launch at login")
                Text(SettingsStatusText.launchAtLoginCaption(model.launchAtLoginStatus))
            }
            if model.launchAtLoginStatus == .requiresApproval {
                LabeledContent {
                    Button("Open Login Items…") {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                } label: {
                    Text("Approval needed")
                    Text("Allow Restless Comet in System Settings › General › Login Items.")
                }
            }
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.launchAtLoginStatus == .enabled },
            set: { isOn in
                model.setLaunchAtLogin(isOn)
            }
        )
    }

    private var menuBarSection: some View {
        Section {
            Toggle(isOn: SettingsConfigAccess.binding(model, \.showMenuBarIcon, fallback: true)) {
                Text("Show menu bar icon")
                Text("When hidden, open Restless Comet again to show this window.")
            }
        }
        .disabled(!SettingsConfigAccess.isEditable(model.configStore))
    }

    private var settingsFileSection: some View {
        Section {
            LabeledContent {
                Button("Reveal in Finder") {
                    revealSettingsFile()
                }
                .disabled(!canRevealSettingsFile)
            } label: {
                Text("Location")
                Text(displayPath)
                    .textSelection(.enabled)
            }
            if let problem = SettingsConfigProblem(store: model.configStore) {
                SettingsConfigProblemView(problem: problem)
            }
        } header: {
            Text("Settings File")
        } footer: {
            Text(settingsFileFooter)
        }
    }

    private var displayPath: String {
        (model.configStore.fileURL.path(percentEncoded: false) as NSString).abbreviatingWithTildeInPath
    }

    private var settingsFileFooter: String {
        if model.configStore.status == .missing {
            return "The file is created the first time you change a setting. People and agents can also edit it by hand."
        }
        return "People and agents can also edit this JSON file by hand."
    }

    private var settingsFileExists: Bool {
        FileManager.default.fileExists(atPath: model.configStore.fileURL.path(percentEncoded: false))
    }

    private var settingsFolderURL: URL {
        model.configStore.fileURL.deletingLastPathComponent()
    }

    private var settingsFolderExists: Bool {
        FileManager.default.fileExists(atPath: settingsFolderURL.path(percentEncoded: false))
    }

    private var canRevealSettingsFile: Bool {
        settingsFileExists || settingsFolderExists
    }

    private func revealSettingsFile() {
        if settingsFileExists {
            NSWorkspace.shared.activateFileViewerSelecting([model.configStore.fileURL])
        } else if settingsFolderExists {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: settingsFolderURL.path(percentEncoded: false))
        }
    }

    private var diagnosticsSection: some View {
        Section {
            Toggle(isOn: SettingsConfigAccess.binding(model, \.diagnostics, fallback: false)) {
                Text("Diagnostics")
                Text("Log the source app and host of each link (debug level, for troubleshooting).")
            }
        }
        .disabled(!SettingsConfigAccess.isEditable(model.configStore))
    }

    private var quitSection: some View {
        Section {
            LabeledContent {
                Button("Quit Restless Comet") {
                    model.quit()
                }
            } label: {
                Text("Background app")
                Text("Restless Comet has no Dock icon. Open it again to show this window.")
            }
        }
    }
}
