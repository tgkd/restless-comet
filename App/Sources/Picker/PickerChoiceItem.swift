import AppKit

struct PickerChoiceItem: Identifiable {
    enum Action: Hashable {
        case open(bundleID: String)
        case copy
    }

    let index: Int
    let action: Action
    let title: String
    let icon: NSImage?

    var id: Action {
        action
    }

    var shortcutLabel: String {
        index < 9 ? String(index + 1) : ""
    }
}
