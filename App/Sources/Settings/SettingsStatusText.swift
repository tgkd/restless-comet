import Foundation

enum SettingsStatusText {
    static func defaultBrowser(_ status: DefaultBrowserStatus) -> String {
        switch status {
        case .unknown:
            return "Default browser status unknown"
        case .isDefault:
            return "Restless Comet is the default browser"
        case .partial(let http, let https):
            return "Only partly the default (http: \(yesNo(http)), https: \(yesNo(https)))"
        case .notDefault(let currentName):
            if let currentName {
                return "Not the default — currently \(currentName)"
            }
            return "Not the default"
        }
    }

    static func launchAtLoginCaption(_ status: LaunchAtLoginStatus) -> String {
        switch status {
        case .unavailable:
            return "Not available for this copy of Restless Comet."
        case .requiresApproval:
            return "Waiting for your approval in System Settings."
        case .unknown, .enabled, .disabled:
            return "Starts in the background when you log in."
        }
    }

    private static func yesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }
}
