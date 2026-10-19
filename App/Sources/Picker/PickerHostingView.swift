import SwiftUI

final class PickerHostingView: NSHostingView<PickerContentView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
