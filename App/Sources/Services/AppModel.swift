import AppKit
import Observation
import RestlessCore
import ServiceManagement
import os

enum DefaultBrowserStatus: Equatable {
    case unknown
    case isDefault
    case partial(http: Bool, https: Bool)
    case notDefault(currentName: String?)
}

enum LaunchAtLoginStatus: Equatable {
    case unknown
    case enabled
    case disabled
    case requiresApproval
    case unavailable
}

@Observable
final class AppModel {
    let configStore: ConfigStore
    let selfBundleID: String
    private(set) var installedBrowsers: [BrowserApp] = []
    private(set) var defaultBrowserStatus: DefaultBrowserStatus = .unknown
    private(set) var launchAtLoginStatus: LaunchAtLoginStatus = .unknown
    var lastError: String?

    private let catalog: any BrowserCataloging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.restlesscomet.app", category: "model")
    @ObservationIgnored private var isChangingDefaultBrowser = false

    private static let defaultBrowserUnchangedMessage = "Default browser unchanged."
    private static let unreadableConfigMessage = "The settings file can't be read, so changes are disabled until it's fixed."

    init(configStore: ConfigStore, catalog: any BrowserCataloging, selfBundleID: String) {
        self.configStore = configStore
        self.catalog = catalog
        self.selfBundleID = selfBundleID
    }

    var canMakeDefault: Bool {
        configStore.config != nil && !installedBrowsers.isEmpty
    }

    func refresh() {
        installedBrowsers = catalog.installedBrowsers()
        defaultBrowserStatus = currentDefaultBrowserStatus()
        launchAtLoginStatus = Self.currentLaunchAtLoginStatus()
    }

    func makeDefaultBrowser() async {
        guard !isChangingDefaultBrowser else {
            return
        }
        isChangingDefaultBrowser = true
        defer {
            isChangingDefaultBrowser = false
        }
        do {
            try await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: "http")
            refresh()
            if isDefaultHandler(forScheme: "http") && !isDefaultHandler(forScheme: "https") {
                try await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: "https")
                refresh()
            }
            if defaultBrowserStatus == .isDefault {
                lastError = nil
            } else {
                logger.notice("Default browser request completed without taking both schemes")
                lastError = Self.defaultBrowserUnchangedMessage
            }
        } catch {
            let nsError = error as NSError
            logger.notice("Default browser request failed: domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)")
            refresh()
            lastError = Self.isUserDecline(error) ? Self.defaultBrowserUnchangedMessage : error.localizedDescription
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status != .notRegistered && service.status != .notFound {
                    try service.unregister()
                }
            }
            lastError = nil
        } catch {
            let nsError = error as NSError
            logger.notice("Launch at login change failed: domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)")
            lastError = error.localizedDescription
        }
        launchAtLoginStatus = Self.currentLaunchAtLoginStatus()
    }

    func updateConfig(_ mutate: (inout Config) -> Void) {
        guard var updated = configStore.config else {
            lastError = Self.unreadableConfigMessage
            return
        }
        mutate(&updated)
        do {
            try configStore.save(updated)
            lastError = nil
        } catch {
            lastError = Self.message(for: error)
        }
    }

    func quit() {
        NSApp.terminate(nil)
    }

    private func currentDefaultBrowserStatus() -> DefaultBrowserStatus {
        let httpIsSelf = isDefaultHandler(forScheme: "http")
        let httpsIsSelf = isDefaultHandler(forScheme: "https")
        if httpIsSelf && httpsIsSelf {
            return .isDefault
        }
        if httpIsSelf || httpsIsSelf {
            return .partial(http: httpIsSelf, https: httpsIsSelf)
        }
        return .notDefault(currentName: handlerName(forScheme: "https"))
    }

    private func isDefaultHandler(forScheme scheme: String) -> Bool {
        guard let handlerURL = Self.handlerURL(forScheme: scheme) else {
            return false
        }
        guard let bundleID = Bundle(url: handlerURL)?.bundleIdentifier else {
            return false
        }
        return bundleID.caseInsensitiveCompare(selfBundleID) == .orderedSame
    }

    private func handlerName(forScheme scheme: String) -> String? {
        guard let handlerURL = Self.handlerURL(forScheme: scheme) else {
            return nil
        }
        if let bundleID = Bundle(url: handlerURL)?.bundleIdentifier, let browser = catalog.browser(withBundleID: bundleID) {
            return browser.name
        }
        return handlerURL.deletingPathExtension().lastPathComponent
    }

    private static func handlerURL(forScheme scheme: String) -> URL? {
        guard let probeURL = URL(string: "\(scheme)://example.com") else {
            return nil
        }
        return NSWorkspace.shared.urlForApplication(toOpen: probeURL)
    }

    private static func currentLaunchAtLoginStatus() -> LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        @unknown default:
            return .unknown
        }
    }

    private static func isUserDecline(_ error: any Error) -> Bool {
        if error is CancellationError {
            return true
        }
        if let cocoaError = error as? CocoaError, cocoaError.code == .userCancelled {
            return true
        }
        let nsError = error as NSError
        if nsError.domain == NSOSStatusErrorDomain && nsError.code == userCanceledErr {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isUserDecline(underlying)
        }
        return false
    }

    private static func message(for error: ConfigSaveError) -> String {
        switch error {
        case .fileInvalid:
            return "The settings file on disk can't be read or comes from a newer version, so it won't be overwritten. Fix or remove it to make changes here."
        case .changedExternally:
            return "The settings file changed on disk and was reloaded. Try again."
        case .invalid(let issue):
            return message(for: issue)
        case .writeFailed(let detail):
            return detail.isEmpty ? "The settings file couldn't be saved." : detail
        }
    }

    private static func message(for issue: ConfigIssue) -> String {
        switch issue {
        case .unreadable(let detail):
            return detail.isEmpty ? "The settings file can't be read." : detail
        case .unsupportedSchema(let version):
            return "Settings schema version \(version) isn't supported by this version of the app."
        case .invalid(let problems):
            return problems.isEmpty ? "These settings aren't valid." : problems.joined(separator: "\n")
        }
    }
}
