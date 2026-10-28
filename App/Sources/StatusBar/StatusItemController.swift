import AppKit
import Observation

final class StatusItemController: NSObject {
    private let isShown: () -> Bool
    private let openSettings: () -> Void
    private var statusItem: NSStatusItem?

    init(isShown: @escaping () -> Bool, openSettings: @escaping () -> Void) {
        self.isShown = isShown
        self.openSettings = openSettings
        super.init()
    }

    func install() {
        let shouldShow = withObservationTracking {
            isShown()
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.install()
            }
        }
        if shouldShow {
            showItem()
        } else {
            removeItem()
        }
    }

    private func showItem() {
        guard statusItem == nil else {
            return
        }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = StatusItemIcon.make()
        item.button?.toolTip = Self.appName
        item.menu = makeMenu()
        statusItem = item
    }

    private func removeItem() {
        guard let statusItem else {
            return
        }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    private static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Restless Comet"
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit \(Self.appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
    }
}
