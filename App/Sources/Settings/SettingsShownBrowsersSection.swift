import RestlessCore
import SwiftUI

struct SettingsShownBrowsersSection: View {
    let model: AppModel

    private var isEditable: Bool {
        SettingsConfigAccess.isEditable(model.configStore)
    }

    private var shownBundleIDs: [String] {
        SettingsDeduplication.unique(model.configStore.config?.shownBrowsers ?? [])
    }

    private var hiddenBrowsers: [BrowserApp] {
        let shown = Set(shownBundleIDs)
        return model.installedBrowsers
            .filter { !shown.contains($0.bundleID) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var listHeight: CGFloat {
        let rows = min(shownBundleIDs.count + hiddenBrowsers.count, SettingsMetrics.maxVisibleBrowserRows)
        return CGFloat(rows) * SettingsMetrics.browserRowHeight
    }

    var body: some View {
        Section {
            if shownBundleIDs.isEmpty && hiddenBrowsers.isEmpty {
                Text("No browsers found.")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(shownBundleIDs, id: \.self) { bundleID in
                        row(bundleID: bundleID, browser: installedBrowser(bundleID))
                            .moveDisabled(!isEditable)
                    }
                    .onMove { source, destination in
                        moveShownBrowsers(from: source, to: destination)
                    }
                    ForEach(hiddenBrowsers) { browser in
                        row(bundleID: browser.bundleID, browser: browser)
                    }
                }
                .scrollContentBackground(.hidden)
                .frame(height: listHeight)
            }
        } header: {
            Text("Shown in Picker")
        } footer: {
            Text("Browsers shown in the picker, in this order. Drag to reorder.")
        }
    }

    private func row(bundleID: String, browser: BrowserApp?) -> some View {
        let name = browser?.name ?? bundleID
        return HStack(spacing: 8) {
            Toggle("Show \(name)", isOn: membershipBinding(bundleID))
                .toggleStyle(.checkbox)
                .labelsHidden()
            if let browser {
                Image(nsImage: SettingsAppDirectory.smallIcon(for: browser))
                Text(name)
            } else {
                Image(nsImage: SettingsAppDirectory.smallIcon(for: bundleID))
                    .opacity(0.5)
                Text(name)
                    .foregroundStyle(.secondary)
                Text("not installed")
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func installedBrowser(_ bundleID: String) -> BrowserApp? {
        model.installedBrowsers.first { $0.bundleID == bundleID }
    }

    private func membershipBinding(_ bundleID: String) -> Binding<Bool> {
        Binding(
            get: { model.configStore.config?.shownBrowsers.contains(bundleID) ?? false },
            set: { isShown in
                model.updateConfig { config in
                    if isShown {
                        if !config.shownBrowsers.contains(bundleID) {
                            config.shownBrowsers.append(bundleID)
                        }
                    } else {
                        config.shownBrowsers.removeAll { $0 == bundleID }
                    }
                }
            }
        )
    }

    private func moveShownBrowsers(from source: IndexSet, to destination: Int) {
        guard isEditable else {
            return
        }
        model.updateConfig { config in
            var order = SettingsDeduplication.unique(config.shownBrowsers)
            order.move(fromOffsets: source, toOffset: destination)
            config.shownBrowsers = order
        }
    }
}
