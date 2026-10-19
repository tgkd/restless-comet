import AppKit
import RestlessCore
import UniformTypeIdentifiers

enum SettingsAppDirectory {
    private static var resolvedURLs: [String: URL] = [:]
    private static var unresolvedBundleIDs: Set<String> = []
    private static var iconsByBundleID: [String: NSImage] = [:]
    private static var iconsByPath: [String: NSImage] = [:]

    static func reset() {
        resolvedURLs.removeAll()
        unresolvedBundleIDs.removeAll()
        iconsByBundleID.removeAll()
        iconsByPath.removeAll()
    }

    static func applicationURL(for bundleID: String) -> URL? {
        if let url = resolvedURLs[bundleID] {
            return url
        }
        if bundleID.isEmpty || unresolvedBundleIDs.contains(bundleID) {
            return nil
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            unresolvedBundleIDs.insert(bundleID)
            return nil
        }
        resolvedURLs[bundleID] = url
        return url
    }

    static func name(for bundleID: String, browsers: [BrowserApp]) -> String {
        if let browser = browsers.first(where: { $0.bundleID == bundleID }) {
            return browser.name
        }
        guard let url = applicationURL(for: bundleID) else {
            return bundleID
        }
        let displayName = FileManager.default.displayName(atPath: url.path(percentEncoded: false))
        if displayName.hasSuffix(".app") {
            return String(displayName.dropLast(4))
        }
        return displayName
    }

    static func smallIcon(for bundleID: String) -> NSImage {
        if let icon = iconsByBundleID[bundleID] {
            return icon
        }
        let icon: NSImage
        if let url = applicationURL(for: bundleID) {
            icon = resized(NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false)))
        } else {
            icon = resized(NSWorkspace.shared.icon(for: .application))
        }
        iconsByBundleID[bundleID] = icon
        return icon
    }

    static func smallIcon(for browser: BrowserApp) -> NSImage {
        let path = browser.appURL.path(percentEncoded: false)
        if let icon = iconsByPath[path] {
            return icon
        }
        let icon = resized(browser.icon)
        iconsByPath[path] = icon
        return icon
    }

    private static func resized(_ image: NSImage) -> NSImage {
        let copy = (image.copy() as? NSImage) ?? image
        copy.size = NSSize(width: SettingsMetrics.iconSize, height: SettingsMetrics.iconSize)
        return copy
    }
}
