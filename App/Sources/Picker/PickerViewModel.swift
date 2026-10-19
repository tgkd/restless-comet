import AppKit
import Observation
import RestlessCore

@Observable
final class PickerViewModel {
    private(set) var items: [PickerChoiceItem] = []
    private(set) var noticeText: String?
    private(set) var pendingCount = 0
    private(set) var highlightedIndex: Int?

    func present(_ presentation: PickerPresentation) {
        items = presentation.choices.enumerated().map { entry in
            PickerChoiceItem(index: entry.offset, browser: entry.element, icon: entry.element.icon)
        }
        noticeText = Self.noticeText(for: presentation.notice, choices: presentation.choices)
        pendingCount = presentation.pendingCount
        highlightedIndex = items.isEmpty ? nil : 0
    }

    func updatePendingCount(_ count: Int) {
        guard pendingCount != count else {
            return
        }
        pendingCount = count
    }

    func highlight(_ index: Int) {
        guard items.indices.contains(index), highlightedIndex != index else {
            return
        }
        highlightedIndex = index
    }

    func moveHighlight(by offset: Int) {
        guard let current = highlightedIndex, !items.isEmpty else {
            return
        }
        highlight(min(max(current + offset, 0), items.count - 1))
    }

    private static func noticeText(for notice: PickerNotice?, choices: [BrowserApp]) -> String? {
        switch notice {
        case .targetUnavailable(let bundleID)?:
            return "\(bundleID) isn't installed — pick a browser"
        case .openFailed(let bundleID)?:
            let name = choices.first { $0.bundleID == bundleID }?.name ?? bundleID
            return "Couldn't open in \(name) — pick another"
        case .configUnavailable?:
            return "Settings file can't be read — pick a browser"
        case nil:
            return choices.isEmpty ? "No browsers to choose from" : nil
        }
    }
}
