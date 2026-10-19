import AppKit
import RestlessCore

final class PickerPanelController: PickerPresenting {
    init(openSettings: @escaping () -> Void) {}

    func show(_ presentation: PickerPresentation, onOutcome: @escaping @MainActor (PickerOutcome) -> Void) {}

    func updatePendingCount(_ count: Int) {}

    func close() {}
}
