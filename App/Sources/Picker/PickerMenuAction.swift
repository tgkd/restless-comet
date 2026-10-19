import AppKit

final class PickerMenuAction: NSObject {
    private let handler: () -> Void

    private init(handler: @escaping () -> Void) {
        self.handler = handler
        super.init()
    }

    static func item(title: String, keyEquivalent: String = "", handler: @escaping () -> Void) -> NSMenuItem {
        let action = PickerMenuAction(handler: handler)
        let item = NSMenuItem(title: title, action: #selector(PickerMenuAction.invoke(_:)), keyEquivalent: keyEquivalent)
        item.target = action
        item.representedObject = action
        return item
    }

    @objc private func invoke(_ sender: Any?) {
        handler()
    }
}
