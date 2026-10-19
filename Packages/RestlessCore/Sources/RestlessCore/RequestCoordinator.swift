import Foundation
import os

@MainActor
public final class RequestCoordinator {
    public typealias Routing = (LinkRequest, Config, String) -> RouteDecision

    private enum PickerReason {
        case prompt(shownBrowsers: [String])
        case configUnavailable
        case targetUnavailable(bundleID: String)
        case openFailed(bundleID: String)
    }

    private struct WaitingRequest {
        let request: LinkRequest
        let reason: PickerReason
    }

    private struct ShownPresentation {
        let serial: Int
        let presentation: PickerPresentation
    }

    private enum LogCode: String {
        case routedAlternative = "routed.alternative"
        case routedRule = "routed.rule"
        case routedDefault = "routed.default"
        case routedPrompt = "routed.prompt"
        case configUnavailable = "config.unavailable"
        case targetUnavailable = "target.unavailable"
        case opened
        case openFailed = "open.failed"
        case shown
        case chose
        case copied
        case cancelled
        case cancelledAll = "cancelled.all"
        case dropped
        case outcomeIgnored = "outcome.ignored"

        var level: OSLogType {
            switch self {
            case .configUnavailable, .targetUnavailable, .openFailed:
                return .error
            default:
                return .info
            }
        }
    }

    private let selfBundleID: String
    private let readConfig: @MainActor () -> Config?
    private let catalog: any BrowserCataloging
    private let opener: any BrowserOpening
    private let picker: any PickerPresenting
    private let route: Routing
    private let logger: Logger
    private var waiting: [WaitingRequest] = []
    private var shown: ShownPresentation?
    private var lastPresentationSerial = 0
    private var openTasks: [UUID: Task<Void, Never>] = [:]

    public init(
        selfBundleID: String,
        config: @escaping @MainActor () -> Config?,
        catalog: any BrowserCataloging,
        opener: any BrowserOpening,
        picker: any PickerPresenting,
        route: @escaping Routing = Router.route
    ) {
        self.selfBundleID = selfBundleID
        self.readConfig = config
        self.catalog = catalog
        self.opener = opener
        self.picker = picker
        self.route = route
        self.logger = Logger(subsystem: selfBundleID, category: "requests")
    }

    public var pendingCount: Int {
        waiting.count + (shown == nil ? 0 : 1)
    }

    public func handle(_ request: LinkRequest) {
        guard let config = readConfig() else {
            log(.configUnavailable, request.id)
            admit(WaitingRequest(request: request, reason: .configUnavailable))
            return
        }
        if config.diagnostics {
            logDiagnostics(for: request)
        }
        switch route(request, config, selfBundleID) {
        case .open(let bundleID, let reason):
            log(routedCode(for: reason), request.id)
            guard let browser = resolvedBrowser(bundleID) else {
                log(.targetUnavailable, request.id)
                admit(WaitingRequest(request: request, reason: .targetUnavailable(bundleID: bundleID)))
                return
            }
            startOpen(request, in: browser)
        case .prompt:
            log(.routedPrompt, request.id)
            admit(WaitingRequest(request: request, reason: .prompt(shownBrowsers: config.shownBrowsers)))
        }
    }

    func settle() async {
        while let task = openTasks.values.first {
            await task.value
        }
    }

    private func admit(_ entry: WaitingRequest) {
        waiting.append(entry)
        presentOrUpdatePendingCount()
    }

    private func readmitAtFront(_ entry: WaitingRequest) {
        waiting.insert(entry, at: 0)
        presentOrUpdatePendingCount()
    }

    private func presentOrUpdatePendingCount() {
        guard shown != nil else {
            advance()
            return
        }
        picker.updatePendingCount(pendingCount)
    }

    private func advance() {
        guard !waiting.isEmpty else {
            picker.close()
            return
        }
        present(waiting.removeFirst())
    }

    private func present(_ entry: WaitingRequest) {
        lastPresentationSerial += 1
        let serial = lastPresentationSerial
        let requestID = entry.request.id
        let presentation = PickerPresentation(
            request: entry.request,
            choices: choices(for: entry.reason),
            notice: notice(for: entry.reason),
            pendingCount: waiting.count + 1
        )
        shown = ShownPresentation(serial: serial, presentation: presentation)
        log(.shown, requestID)
        picker.show(presentation) { [weak self] outcome in
            self?.receive(outcome, fromPresentation: serial, of: requestID)
        }
    }

    private func receive(_ outcome: PickerOutcome, fromPresentation serial: Int, of requestID: UUID) {
        guard let current = shown, current.serial == serial else {
            log(.outcomeIgnored, requestID)
            return
        }
        shown = nil
        let request = current.presentation.request
        switch outcome {
        case .chose(let bundleID):
            log(.chose, request.id)
            if let browser = resolvedBrowser(bundleID) {
                startOpen(request, in: browser)
            } else {
                log(.targetUnavailable, request.id)
                waiting.insert(WaitingRequest(request: request, reason: .targetUnavailable(bundleID: bundleID)), at: 0)
            }
        case .copied:
            log(.copied, request.id)
        case .cancel:
            log(.cancelled, request.id)
        case .cancelAll:
            log(.cancelledAll, request.id)
            for entry in waiting {
                log(.dropped, entry.request.id)
            }
            waiting.removeAll()
        }
        advance()
    }

    private func startOpen(_ request: LinkRequest, in browser: BrowserApp) {
        openTasks[request.id] = Task { @MainActor in
            do {
                try await self.opener.open(request.url, in: browser)
                self.finishOpen(of: request, failedBundleID: nil)
            } catch {
                self.finishOpen(of: request, failedBundleID: browser.bundleID)
            }
        }
    }

    private func finishOpen(of request: LinkRequest, failedBundleID: String?) {
        openTasks[request.id] = nil
        guard let failedBundleID else {
            log(.opened, request.id)
            return
        }
        log(.openFailed, request.id)
        readmitAtFront(WaitingRequest(request: request, reason: .openFailed(bundleID: failedBundleID)))
    }

    private func resolvedBrowser(_ bundleID: String) -> BrowserApp? {
        guard bundleID != selfBundleID,
              let browser = catalog.browser(withBundleID: bundleID),
              browser.bundleID != selfBundleID
        else {
            return nil
        }
        return browser
    }

    private func choices(for reason: PickerReason) -> [BrowserApp] {
        switch reason {
        case .prompt(let shownBrowsers):
            let preferred = withoutDuplicates(shownBrowsers.compactMap { resolvedBrowser($0) })
            if preferred.isEmpty {
                return installedChoices(excluding: nil)
            }
            return preferred
        case .configUnavailable:
            return installedChoices(excluding: nil)
        case .targetUnavailable(let bundleID), .openFailed(let bundleID):
            return installedChoices(excluding: bundleID)
        }
    }

    private func installedChoices(excluding excludedBundleID: String?) -> [BrowserApp] {
        let candidates = catalog.installedBrowsers().filter { browser in
            browser.bundleID != selfBundleID && browser.bundleID != excludedBundleID
        }
        return withoutDuplicates(candidates)
    }

    private func withoutDuplicates(_ browsers: [BrowserApp]) -> [BrowserApp] {
        var seen: Set<String> = []
        return browsers.filter { browser in
            seen.insert(browser.bundleID).inserted
        }
    }

    private func notice(for reason: PickerReason) -> PickerNotice? {
        switch reason {
        case .prompt:
            return nil
        case .configUnavailable:
            return .configUnavailable
        case .targetUnavailable(let bundleID):
            return .targetUnavailable(bundleID: bundleID)
        case .openFailed(let bundleID):
            return .openFailed(bundleID: bundleID)
        }
    }

    private func routedCode(for reason: RouteReason) -> LogCode {
        switch reason {
        case .alternative:
            return .routedAlternative
        case .rule:
            return .routedRule
        case .defaultBrowser:
            return .routedDefault
        }
    }

    private func log(_ code: LogCode, _ requestID: UUID) {
        logger.log(level: code.level, "\(requestID.uuidString, privacy: .public) \(code.rawValue, privacy: .public)")
    }

    private func logDiagnostics(for request: LinkRequest) {
        let source = request.sourceBundleID ?? "unknown"
        let host = request.url.host(percentEncoded: false) ?? "none"
        logger.debug("\(request.id.uuidString, privacy: .public) source \(source, privacy: .public) host \(host, privacy: .public)")
    }
}
