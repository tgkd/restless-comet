import Foundation

enum ConfigLocation {
    static func fileURL(bundleID: String) -> URL {
        URL.applicationSupportDirectory
            .appending(path: bundleID, directoryHint: .isDirectory)
            .appending(path: "config.json", directoryHint: .notDirectory)
    }
}
