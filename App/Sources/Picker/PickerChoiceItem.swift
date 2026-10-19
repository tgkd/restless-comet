import AppKit
import RestlessCore

struct PickerChoiceItem: Identifiable {
    let index: Int
    let browser: BrowserApp
    let icon: NSImage

    var id: Int {
        index
    }

    var shortcutLabel: String {
        index < 9 ? String(index + 1) : ""
    }
}
