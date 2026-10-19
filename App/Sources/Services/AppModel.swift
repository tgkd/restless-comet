import AppKit
import Observation
import RestlessCore

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

    init(configStore: ConfigStore, catalog: any BrowserCataloging, selfBundleID: String) {
        self.configStore = configStore
        self.selfBundleID = selfBundleID
    }

    var canMakeDefault: Bool {
        false
    }

    func refresh() {}

    func makeDefaultBrowser() async {}

    func setLaunchAtLogin(_ enabled: Bool) {}

    func updateConfig(_ mutate: (inout Config) -> Void) {}

    func quit() {}
}
