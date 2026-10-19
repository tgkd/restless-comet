import AppKit
import RestlessCore
import SwiftUI

struct SettingsBrowserLabel: View {
    let title: String
    let icon: NSImage

    init(browser: BrowserApp) {
        title = browser.name
        icon = SettingsAppDirectory.smallIcon(for: browser)
    }

    init(missingBundleID bundleID: String) {
        title = "\(bundleID) (not installed)"
        icon = SettingsAppDirectory.smallIcon(for: bundleID)
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(nsImage: icon)
        }
    }
}
