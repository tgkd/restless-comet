import AppKit
import RestlessCore

final class WorkspaceBrowserCatalog: BrowserCataloging {
    private static let familyKey = "RestlessCometAppFamily"

    private let selfBundleID: String
    private let ownFamily = Bundle.main.object(forInfoDictionaryKey: familyKey) as? String

    init(selfBundleID: String) {
        self.selfBundleID = selfBundleID
    }

    func installedBrowsers() -> [BrowserApp] {
        guard let probeURL = URL(string: "https://example.com") else {
            return []
        }
        let workspace = NSWorkspace.shared
        var seenBundleIDs: Set<String> = []
        var browsers: [BrowserApp] = []
        for candidateURL in workspace.urlsForApplications(toOpen: probeURL) {
            guard let bundle = Bundle(url: candidateURL),
                  let bundleID = bundle.bundleIdentifier,
                  !isSelf(bundleID),
                  !isOwnFamily(bundle)
            else {
                continue
            }
            guard seenBundleIDs.insert(bundleID.lowercased()).inserted else {
                continue
            }
            let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) ?? candidateURL
            browsers.append(makeBrowser(bundleID: bundleID, appURL: appURL))
        }
        return browsers.sorted(by: Self.isOrderedBefore)
    }

    func browser(withBundleID bundleID: String) -> BrowserApp? {
        guard !isSelf(bundleID) else {
            return nil
        }
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        guard !isOwnFamily(Bundle(url: appURL)) else {
            return nil
        }
        return makeBrowser(bundleID: bundleID, appURL: appURL)
    }

    private func isSelf(_ bundleID: String) -> Bool {
        bundleID.caseInsensitiveCompare(selfBundleID) == .orderedSame
    }

    private func isOwnFamily(_ bundle: Bundle?) -> Bool {
        guard let ownFamily, let family = bundle?.object(forInfoDictionaryKey: Self.familyKey) as? String else {
            return false
        }
        return family == ownFamily
    }

    private func makeBrowser(bundleID: String, appURL: URL) -> BrowserApp {
        BrowserApp(bundleID: bundleID, name: Self.displayName(ofApplicationAt: appURL), appURL: appURL)
    }

    private static func displayName(ofApplicationAt appURL: URL) -> String {
        let bundle = Bundle(url: appURL)
        for key in ["CFBundleDisplayName", "CFBundleName"] {
            guard let value = bundle?.object(forInfoDictionaryKey: key) as? String else {
                continue
            }
            let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                return name
            }
        }
        return appURL.deletingPathExtension().lastPathComponent
    }

    private static func isOrderedBefore(_ lhs: BrowserApp, _ rhs: BrowserApp) -> Bool {
        switch lhs.name.localizedStandardCompare(rhs.name) {
        case .orderedAscending:
            return true
        case .orderedDescending:
            return false
        case .orderedSame:
            return lhs.bundleID < rhs.bundleID
        }
    }
}
