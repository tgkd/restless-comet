struct PickerActions {
    let choose: (Int) -> Void
    let hover: (Int) -> Void
    let copy: () -> Void
    let showMenu: () -> Void
}
