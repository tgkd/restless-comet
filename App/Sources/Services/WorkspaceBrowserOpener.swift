import AppKit
import RestlessCore

final class WorkspaceBrowserOpener: BrowserOpening {
    func open(_ url: URL, in browser: BrowserApp) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        _ = try await NSWorkspace.shared.open([url], withApplicationAt: browser.appURL, configuration: configuration)
    }
}
