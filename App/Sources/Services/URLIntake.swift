import AppKit
import RestlessCore

final class URLIntake: NSObject {
    private(set) var hasReceivedRequests = false

    init(onRequest: @escaping (LinkRequest) -> Void) {
        super.init()
    }

    func install() {}

    func receive(_ urls: [URL]) {}
}
