import AppKit
import SwiftUI

final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private let window: NSWindow
    private var hasBeenShown = false

    init(model: AppModel) {
        self.model = model
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(
            SettingsWindowController.tab(title: "General", symbolName: "gearshape", rootView: SettingsGeneralView(model: model))
        )
        tabs.addTabViewItem(
            SettingsWindowController.tab(title: "Browsers", symbolName: "globe", rootView: SettingsBrowsersView(model: model))
        )
        tabs.addTabViewItem(
            SettingsWindowController.tab(title: "Rules", symbolName: "arrow.triangle.branch", rootView: SettingsRulesView(model: model))
        )
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        self.window = window
        super.init()
        window.delegate = self
    }

    func show() {
        NSApp.activate()
        if !hasBeenShown {
            window.center()
            hasBeenShown = true
        }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        SettingsAppDirectory.reset()
        model.refresh()
    }

    private static func tab<Content: View>(title: String, symbolName: String, rootView: Content) -> NSTabViewItem {
        let controller = NSHostingController(rootView: rootView)
        controller.sizingOptions = [.preferredContentSize]
        controller.title = title
        let item = NSTabViewItem(viewController: controller)
        item.label = title
        item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        return item
    }
}
