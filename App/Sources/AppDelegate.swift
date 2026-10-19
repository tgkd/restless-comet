import AppKit
import RestlessCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let selfBundleID = Bundle.main.bundleIdentifier ?? "com.restlesscomet.app"

    private lazy var configStore = ConfigStore(
        fileURL: ConfigLocation.fileURL(bundleID: selfBundleID),
        selfBundleID: selfBundleID
    )
    private lazy var catalog = WorkspaceBrowserCatalog(selfBundleID: selfBundleID)
    private lazy var opener = WorkspaceBrowserOpener()
    private lazy var model = AppModel(configStore: configStore, catalog: catalog, selfBundleID: selfBundleID)
    private lazy var settings = SettingsWindowController(model: model)
    private lazy var picker = PickerPanelController(openSettings: { [weak self] in
        self?.showSettings()
    })
    private lazy var coordinator = RequestCoordinator(
        selfBundleID: selfBundleID,
        config: { [configStore] in
            configStore.reloadIfChanged()
            return configStore.config
        },
        catalog: catalog,
        opener: opener,
        picker: picker
    )
    private lazy var intake = URLIntake(onRequest: { [weak self] request in
        self?.coordinator.handle(request)
    })

    func applicationWillFinishLaunching(_ notification: Notification) {
        configStore.load()
        intake.install()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !LaunchReason.isLoginItemLaunch() && !intake.hasReceivedRequests {
            showSettings()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        intake.receive(urls)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    private func showSettings() {
        model.refresh()
        settings.show()
    }
}
