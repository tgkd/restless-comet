import AppKit

enum StatusItemIcon {
    static func make(pointSize: CGFloat = 15) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        let image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "Restless Comet")?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }
}
