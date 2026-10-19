import AppKit

struct PickerPlacement {
    private static let pointerOffset: CGFloat = 6

    let topLeft: NSPoint
    let visibleFrame: NSRect?

    init(pointer: NSPoint) {
        topLeft = NSPoint(x: pointer.x + Self.pointerOffset, y: pointer.y - Self.pointerOffset)
        visibleFrame = Self.screen(containing: pointer)?.visibleFrame
    }

    func frame(for size: NSSize) -> NSRect {
        var left = topLeft.x
        var top = topLeft.y
        if let visibleFrame {
            left = max(visibleFrame.minX, min(left, visibleFrame.maxX - size.width))
            top = min(visibleFrame.maxY, max(top, visibleFrame.minY + size.height))
        }
        return NSRect(
            x: left.rounded(.down),
            y: (top - size.height).rounded(.down),
            width: size.width,
            height: size.height
        )
    }

    private static func screen(containing point: NSPoint) -> NSScreen? {
        let match = NSScreen.screens.first { screen in
            let frame = screen.frame
            return point.x >= frame.minX && point.x <= frame.maxX && point.y >= frame.minY && point.y <= frame.maxY
        }
        return match ?? NSScreen.main
    }
}
