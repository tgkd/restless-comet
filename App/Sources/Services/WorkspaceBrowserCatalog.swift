import AppKit
import RestlessCore

final class WorkspaceBrowserCatalog: BrowserCataloging {
    init(selfBundleID: String) {}

    func installedBrowsers() -> [BrowserApp] {
        []
    }

    func browser(withBundleID bundleID: String) -> BrowserApp? {
        nil
    }
}
