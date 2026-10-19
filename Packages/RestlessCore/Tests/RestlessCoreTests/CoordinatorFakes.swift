import Foundation
@testable import RestlessCore

enum CoordinatorFixture {
    static let selfBundleID = "com.restlesscomet.app"
    static let ownApp = browser(selfBundleID, name: "Restless Comet")
    static let safari = browser("com.apple.Safari", name: "Safari")
    static let chrome = browser("com.google.Chrome", name: "Google Chrome")
    static let firefox = browser("org.mozilla.firefox", name: "Firefox")

    static func browser(_ bundleID: String, name: String) -> BrowserApp {
        BrowserApp(bundleID: bundleID, name: name, appURL: URL(filePath: "/Applications/\(name).app"))
    }
}

@MainActor
final class CoordinatorFakeCatalog: BrowserCataloging {
    var installed: [BrowserApp]

    init(installed: [BrowserApp]) {
        self.installed = installed
    }

    func installedBrowsers() -> [BrowserApp] {
        installed
    }

    func browser(withBundleID bundleID: String) -> BrowserApp? {
        installed.first { $0.bundleID == bundleID }
    }
}

@MainActor
final class CoordinatorFakeOpener: BrowserOpening {
    struct Call: Equatable {
        let url: URL
        let bundleID: String
    }

    struct OpenError: Error {}

    var failingBundleIDs: Set<String>
    private(set) var calls: [Call] = []

    init(failingBundleIDs: Set<String> = []) {
        self.failingBundleIDs = failingBundleIDs
    }

    func open(_ url: URL, in browser: BrowserApp) async throws {
        calls.append(Call(url: url, bundleID: browser.bundleID))
        if failingBundleIDs.contains(browser.bundleID) {
            throw OpenError()
        }
    }
}

@MainActor
final class CoordinatorFakePicker: PickerPresenting {
    enum Event: Equatable {
        case show(PickerPresentation)
        case updatePendingCount(Int)
        case close
    }

    private enum ScreenState {
        case hidden
        case awaitingOutcome
        case decided
    }

    private(set) var events: [Event] = []
    private(set) var violations: [String] = []
    private var handlers: [@MainActor (PickerOutcome) -> Void] = []
    private var state = ScreenState.hidden

    func show(_ presentation: PickerPresentation, onOutcome: @escaping @MainActor (PickerOutcome) -> Void) {
        if state == .awaitingOutcome {
            violations.append("show while the previous presentation still awaits its outcome")
        }
        events.append(.show(presentation))
        handlers.append(onOutcome)
        state = .awaitingOutcome
    }

    func updatePendingCount(_ count: Int) {
        if state != .awaitingOutcome {
            violations.append("updatePendingCount(\(count)) while no presentation awaits an outcome")
        }
        events.append(.updatePendingCount(count))
    }

    func close() {
        if state != .decided {
            violations.append("close while \(state)")
        }
        events.append(.close)
        state = .hidden
    }

    func deliver(_ outcome: PickerOutcome) {
        guard state == .awaitingOutcome, let handler = handlers.last else {
            violations.append("deliver(\(outcome)) while no presentation awaits an outcome")
            return
        }
        state = .decided
        handler(outcome)
        if state == .decided {
            violations.append("outcome \(outcome) was followed by neither show nor close")
        }
    }

    func redeliver(_ outcome: PickerOutcome, toShowAt index: Int) {
        handlers[index](outcome)
    }
}

final class CoordinatorRouteStub {
    struct Call: Equatable {
        let requestID: UUID
        let config: Config
        let selfBundleID: String
    }

    var fallback = RouteDecision.prompt
    var decisions: [UUID: RouteDecision] = [:]
    private(set) var calls: [Call] = []

    func route(_ request: LinkRequest, config: Config, selfBundleID: String) -> RouteDecision {
        calls.append(Call(requestID: request.id, config: config, selfBundleID: selfBundleID))
        return decisions[request.id] ?? fallback
    }
}

@MainActor
final class CoordinatorConfigSource {
    var config: Config?
    private(set) var reads = 0

    init(config: Config?) {
        self.config = config
    }

    func read() -> Config? {
        reads += 1
        return config
    }
}

@MainActor
final class CoordinatorHarness {
    let catalog: CoordinatorFakeCatalog
    let opener: CoordinatorFakeOpener
    let picker: CoordinatorFakePicker
    let router: CoordinatorRouteStub
    let configSource: CoordinatorConfigSource
    let coordinator: RequestCoordinator

    init(installed: [BrowserApp], config: Config?, failing: Set<String> = []) {
        let catalog = CoordinatorFakeCatalog(installed: installed)
        let opener = CoordinatorFakeOpener(failingBundleIDs: failing)
        let picker = CoordinatorFakePicker()
        let router = CoordinatorRouteStub()
        let configSource = CoordinatorConfigSource(config: config)
        self.catalog = catalog
        self.opener = opener
        self.picker = picker
        self.router = router
        self.configSource = configSource
        self.coordinator = RequestCoordinator(
            selfBundleID: CoordinatorFixture.selfBundleID,
            config: {
                configSource.read()
            },
            catalog: catalog,
            opener: opener,
            picker: picker,
            route: { request, config, selfBundleID in
                router.route(request, config: config, selfBundleID: selfBundleID)
            }
        )
    }
}
