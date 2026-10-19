import AppKit
import RestlessCore

extension BrowserApp {
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: appURL.path(percentEncoded: false))
    }
}
