import AppKit
import RestlessCore
import SwiftUI

final class PickerPanelController: PickerPresenting {
    private static let menuURLTitleLimit = 160

    private let openSettings: () -> Void
    private let model = PickerViewModel()
    private lazy var hostingView = PickerHostingView(
        rootView: PickerContentView(model: model, actions: makeActions())
    )
    private lazy var panel = PickerPanel(content: hostingView)
    private var presentation: PickerPresentation?
    private var outcomeHandler: (@MainActor (PickerOutcome) -> Void)?
    private var lastDeliveredOutcome: PickerOutcome?
    private var placement: PickerPlacement?
    private var pointerLocationAtShow: NSPoint?
    private var outsideClickMonitor: Any?
    private var resizeObserver: (any NSObjectProtocol)?

    init(openSettings: @escaping () -> Void) {
        self.openSettings = openSettings
        panel.keyHandler = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.keepPanelInPlace()
            }
        }
    }

    func show(_ presentation: PickerPresentation, onOutcome: @escaping @MainActor (PickerOutcome) -> Void) {
        let pointer = NSEvent.mouseLocation
        let keepsPosition = panel.isVisible && placement != nil
        self.presentation = presentation
        outcomeHandler = onOutcome
        lastDeliveredOutcome = nil
        pointerLocationAtShow = pointer
        model.present(presentation)
        if !keepsPosition {
            placement = PickerPlacement(pointer: pointer)
        }
        fitPanelToContent()
        if NSApp.isHidden {
            NSApp.unhideWithoutActivation()
        }
        panel.orderFrontRegardless()
        panel.makeKey()
        installOutsideClickMonitor()
    }

    func updatePendingCount(_ count: Int) {
        model.updatePendingCount(count)
        if panel.isVisible {
            fitPanelToContent()
        }
    }

    func close() {
        outcomeHandler = nil
        removeOutsideClickMonitor()
        let wasVisible = panel.isVisible
        panel.orderOut(nil)
        placement = nil
        presentation = nil
        pointerLocationAtShow = nil
        if wasVisible {
            handFocusBackIfNeeded()
        }
    }

    private var isAwaitingOutcome: Bool {
        outcomeHandler != nil
    }

    private var hasOtherVisibleWindow: Bool {
        NSApp.windows.contains { window in
            window !== panel && window.styleMask.contains(.titled) && (window.isVisible || window.isMiniaturized)
        }
    }

    private func makeActions() -> PickerActions {
        PickerActions(
            choose: { [weak self] index in
                self?.choose(at: index)
            },
            hover: { [weak self] index in
                self?.hover(at: index)
            },
            copy: { [weak self] in
                self?.copyURL()
            },
            showMenu: { [weak self] in
                self?.showMenu()
            }
        )
    }

    private func deliver(_ outcome: PickerOutcome) {
        guard let handler = outcomeHandler else {
            return
        }
        outcomeHandler = nil
        lastDeliveredOutcome = outcome
        handler(outcome)
    }

    private func choose(at index: Int) {
        guard isAwaitingOutcome, let presentation, presentation.choices.indices.contains(index) else {
            return
        }
        deliver(.chose(bundleID: presentation.choices[index].bundleID))
    }

    private func chooseHighlighted() {
        guard let index = model.highlightedIndex else {
            return
        }
        choose(at: index)
    }

    private func copyURL() {
        guard isAwaitingOutcome, let presentation else {
            return
        }
        let pasteboard = NSPasteboard.general
        _ = pasteboard.clearContents()
        _ = pasteboard.setString(presentation.request.url.absoluteString, forType: .string)
        deliver(.copied)
    }

    private func hover(at index: Int) {
        guard isAwaitingOutcome else {
            return
        }
        if let pointerLocationAtShow {
            guard NSEvent.mouseLocation != pointerLocationAtShow else {
                return
            }
            self.pointerLocationAtShow = nil
        }
        model.highlight(index)
    }

    private func moveHighlight(by offset: Int) {
        guard isAwaitingOutcome else {
            return
        }
        model.moveHighlight(by: offset)
    }

    private func openSettingsFromMenu() {
        guard isAwaitingOutcome else {
            return
        }
        openSettings()
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard let command = PickerKeyCommand(event: event) else {
            return false
        }
        switch command {
        case .copy:
            copyURL()
        case .cancel:
            deliver(.cancel)
        case .chooseHighlighted:
            chooseHighlighted()
        case .choose(let index):
            choose(at: index)
        case .moveHighlight(let offset):
            moveHighlight(by: offset)
        }
        return true
    }

    private func showMenu() {
        guard isAwaitingOutcome, let presentation else {
            return
        }
        let url = presentation.request.url
        let menu = NSMenu()
        menu.autoenablesItems = false
        let urlItem = NSMenuItem(title: Self.menuTitle(for: url), action: nil, keyEquivalent: "")
        urlItem.isEnabled = false
        urlItem.toolTip = url.absoluteString
        menu.addItem(urlItem)
        menu.addItem(.separator())
        menu.addItem(PickerMenuAction.item(title: "Copy", keyEquivalent: "c") { [weak self] in
            self?.copyURL()
        })
        menu.addItem(PickerMenuAction.item(title: "Settings…") { [weak self] in
            self?.openSettingsFromMenu()
        })
        if model.pendingCount > 1 {
            menu.addItem(.separator())
            menu.addItem(PickerMenuAction.item(title: "Cancel All") { [weak self] in
                self?.deliver(.cancelAll)
            })
        }
        let location = hostingView.convert(panel.mouseLocationOutsideOfEventStream, from: nil)
        _ = menu.popUp(positioning: nil, at: location, in: hostingView)
    }

    private func installOutsideClickMonitor() {
        guard outsideClickMonitor == nil else {
            return
        }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.deliver(.cancel)
        }
    }

    private func removeOutsideClickMonitor() {
        guard let outsideClickMonitor else {
            return
        }
        NSEvent.removeMonitor(outsideClickMonitor)
        self.outsideClickMonitor = nil
    }

    private func fitPanelToContent() {
        guard let placement else {
            return
        }
        let frame = placement.frame(for: hostingView.fittingSize)
        if frame != panel.frame {
            panel.setFrame(frame, display: true)
        }
        panel.invalidateShadow()
    }

    private func keepPanelInPlace() {
        guard panel.isVisible, let placement else {
            return
        }
        let frame = placement.frame(for: panel.frame.size)
        if frame.origin != panel.frame.origin {
            panel.setFrameOrigin(frame.origin)
        }
        panel.invalidateShadow()
    }

    private func handFocusBackIfNeeded() {
        if case .chose? = lastDeliveredOutcome {
            return
        }
        guard NSApp.isActive, !hasOtherVisibleWindow else {
            return
        }
        NSApp.hide(nil)
    }

    private static func menuTitle(for url: URL) -> String {
        let text = url.absoluteString
        guard text.count > menuURLTitleLimit else {
            return text
        }
        let headLength = menuURLTitleLimit * 2 / 3
        let tailLength = menuURLTitleLimit - headLength - 1
        return "\(text.prefix(headLength))…\(text.suffix(tailLength))"
    }
}
