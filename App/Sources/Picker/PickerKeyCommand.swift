import AppKit
import Carbon.HIToolbox

enum PickerKeyCommand {
    case copy
    case cancel
    case chooseHighlighted
    case choose(index: Int)
    case moveHighlight(offset: Int)

    private static let digitKeyCodes: [Int: Int] = [
        kVK_ANSI_1: 1, kVK_ANSI_2: 2, kVK_ANSI_3: 3,
        kVK_ANSI_4: 4, kVK_ANSI_5: 5, kVK_ANSI_6: 6,
        kVK_ANSI_7: 7, kVK_ANSI_8: 8, kVK_ANSI_9: 9,
        kVK_ANSI_Keypad1: 1, kVK_ANSI_Keypad2: 2, kVK_ANSI_Keypad3: 3,
        kVK_ANSI_Keypad4: 4, kVK_ANSI_Keypad5: 5, kVK_ANSI_Keypad6: 6,
        kVK_ANSI_Keypad7: 7, kVK_ANSI_Keypad8: 8, kVK_ANSI_Keypad9: 9,
    ]

    init?(event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option])
        let keyCode = Int(event.keyCode)
        if modifiers == .command {
            guard !event.isARepeat, Self.isCopyKey(event, keyCode: keyCode) else {
                return nil
            }
            self = .copy
            return
        }
        guard modifiers.isEmpty else {
            return nil
        }
        switch keyCode {
        case kVK_LeftArrow:
            self = .moveHighlight(offset: -1)
            return
        case kVK_RightArrow:
            self = .moveHighlight(offset: 1)
            return
        default:
            break
        }
        guard !event.isARepeat else {
            return nil
        }
        switch keyCode {
        case kVK_Escape:
            self = .cancel
        case kVK_Return, kVK_ANSI_KeypadEnter:
            self = .chooseHighlighted
        default:
            guard let number = Self.digit(for: event, keyCode: keyCode) else {
                return nil
            }
            self = .choose(index: number - 1)
        }
    }

    private static func isCopyKey(_ event: NSEvent, keyCode: Int) -> Bool {
        event.charactersIgnoringModifiers?.lowercased() == "c" || keyCode == kVK_ANSI_C
    }

    private static func digit(for event: NSEvent, keyCode: Int) -> Int? {
        if let characters = event.charactersIgnoringModifiers, let value = Int(characters), (1...9).contains(value) {
            return value
        }
        return digitKeyCodes[keyCode]
    }
}
