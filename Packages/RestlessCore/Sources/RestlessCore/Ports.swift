import Foundation

@MainActor
public protocol BrowserCataloging: AnyObject {
    func installedBrowsers() -> [BrowserApp]
    func browser(withBundleID bundleID: String) -> BrowserApp?
}

@MainActor
public protocol BrowserOpening: AnyObject {
    func open(_ url: URL, in browser: BrowserApp) async throws
}

public enum PickerNotice: Sendable, Equatable {
    case targetUnavailable(bundleID: String)
    case openFailed(bundleID: String)
    case configUnavailable
}

public struct PickerPresentation: Sendable, Equatable {
    public let request: LinkRequest
    public let choices: [BrowserApp]
    public let notice: PickerNotice?
    public let pendingCount: Int

    public init(request: LinkRequest, choices: [BrowserApp], notice: PickerNotice?, pendingCount: Int) {
        self.request = request
        self.choices = choices
        self.notice = notice
        self.pendingCount = pendingCount
    }
}

public enum PickerOutcome: Sendable, Equatable {
    case chose(bundleID: String)
    case copied
    case cancel
    case cancelAll
}

@MainActor
public protocol PickerPresenting: AnyObject {
    func show(_ presentation: PickerPresentation, onOutcome: @escaping @MainActor (PickerOutcome) -> Void)
    func updatePendingCount(_ count: Int)
    func close()
}
