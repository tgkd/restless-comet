struct PickerActions {
    let choose: (Int) -> Void
    let hover: (Int) -> Void
    let cancelAll: () -> Void
    let openSettings: () -> Void
}
