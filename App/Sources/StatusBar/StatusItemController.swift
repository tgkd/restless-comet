import AppKit

final class StatusItemController: NSObject {
    private let openSettings: () -> Void
    private var statusItem: NSStatusItem?

    init(openSettings: @escaping () -> Void) {
        self.openSettings = openSettings
        super.init()
    }

    func install() {
        guard statusItem == nil else {
            return
        }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = StatusItemIcon.make()
        item.button?.toolTip = Self.appName
        item.menu = makeMenu()
        statusItem = item
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
