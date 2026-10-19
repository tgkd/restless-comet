import AppKit

enum LaunchReason {
    static func isLoginItemLaunch() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else {
            return false
        }
        guard event.eventClass == AEEventClass(kCoreEventClass), event.eventID == AEEventID(kAEOpenApplication) else {
            return false
        }
        let launchKind = event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue
        return launchKind == OSType(keyAELaunchedAsLogInItem)
    }

    static func isQuietLaunchRequested() -> Bool {
        ProcessInfo.processInfo.arguments.contains("--quiet")
    }
}
