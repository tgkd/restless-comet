import AppKit
import RestlessCore
import os

final class URLIntake: NSObject {
    private(set) var hasReceivedRequests = false
    private let onRequest: (LinkRequest) -> Void
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.restlesscomet.app", category: "intake")
    private static let webSchemes: Set<String> = ["http", "https"]

    init(onRequest: @escaping (LinkRequest) -> Void) {
        self.onRequest = onRequest
        super.init()
    }

    func install() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func receive(_ urls: [URL]) {
        let senderPID = Self.senderPID(of: NSAppleEventManager.shared().currentAppleEvent)
        let sourceBundleID = Self.bundleID(ofSender: senderPID)
        let alternativeRequested = Self.isAlternativeRequested()
        for url in urls {
            emit(LinkRequest(url: url, sourceBundleID: sourceBundleID, alternativeRequested: alternativeRequested))
        }
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        let senderPID = Self.senderPID(of: event)
        let sourceBundleID = Self.bundleID(ofSender: senderPID)
        let alternativeRequested = Self.isAlternativeRequested()
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue else {
            logger.error("Dropped a URL event without a URL string")
            return
        }
        guard let url = URL(string: urlString) else {
            logger.error("Dropped a URL event whose URL could not be parsed")
            return
        }
        let scheme = url.scheme?.lowercased() ?? ""
        guard Self.webSchemes.contains(scheme) else {
            logger.error("Dropped a URL event with unsupported scheme \(scheme, privacy: .public)")
            return
        }
        emit(LinkRequest(url: url, sourceBundleID: sourceBundleID, alternativeRequested: alternativeRequested))
    }

    private func emit(_ request: LinkRequest) {
        hasReceivedRequests = true
        let requestID = request.id.uuidString
        let scheme = request.url.scheme?.lowercased() ?? "none"
        let sourceKnown = request.sourceBundleID != nil
        let alternativeRequested = request.alternativeRequested
        logger.info(
            "Request \(requestID, privacy: .public) received: scheme=\(scheme, privacy: .public) sourceKnown=\(sourceKnown, privacy: .public) alternative=\(alternativeRequested, privacy: .public)"
        )
        onRequest(request)
    }

    private static func senderPID(of event: NSAppleEventDescriptor?) -> pid_t? {
        event?.attributeDescriptor(forKeyword: AEKeyword(keySenderPIDAttr))?.int32Value
    }

    private static func bundleID(ofSender pid: pid_t?) -> String? {
        guard let pid, pid > 0, pid != ProcessInfo.processInfo.processIdentifier else {
            return nil
        }
        return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }

    private static func isAlternativeRequested() -> Bool {
        NSEvent.modifierFlags.contains(.function)
    }
}
