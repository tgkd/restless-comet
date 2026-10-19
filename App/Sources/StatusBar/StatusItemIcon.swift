import AppKit

enum StatusItemIcon {
    nonisolated static func make(pointSize: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else {
                return false
            }
            drawComet(in: context, rect: rect)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Restless Comet"
        return image
    }

    nonisolated private static func drawComet(in context: CGContext, rect: CGRect) {
        let unit = rect.width / 18
        let head = CGPoint(x: rect.minX + 12.1 * unit, y: rect.minY + 12.1 * unit)
        let tip = CGPoint(x: rect.minX + 1.6 * unit, y: rect.minY + 1.6 * unit)
        context.setFillColor(CGColor(gray: 0, alpha: 0.55))
        fillStreak(context, from: head, to: rotated(tip, around: head, degrees: 20, scale: 0.68), halfWidth: 1.5 * unit)
        fillStreak(context, from: head, to: rotated(tip, around: head, degrees: -20, scale: 0.68), halfWidth: 1.5 * unit)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        fillStreak(context, from: head, to: tip, halfWidth: 3 * unit)
        let radius = 3.7 * unit
        context.fillEllipse(in: CGRect(x: head.x - radius, y: head.y - radius, width: radius * 2, height: radius * 2))
    }

    nonisolated private static func fillStreak(_ context: CGContext, from head: CGPoint, to tip: CGPoint, halfWidth: CGFloat) {
        let dx = tip.x - head.x
        let dy = tip.y - head.y
        let length = (dx * dx + dy * dy).squareRoot()
        let offsetX = -dy / length * halfWidth
        let offsetY = dx / length * halfWidth
        context.beginPath()
        context.move(to: CGPoint(x: head.x + offsetX, y: head.y + offsetY))
        context.addLine(to: tip)
        context.addLine(to: CGPoint(x: head.x - offsetX, y: head.y - offsetY))
        context.closePath()
        context.fillPath()
    }

    nonisolated private static func rotated(_ point: CGPoint, around center: CGPoint, degrees: CGFloat, scale: CGFloat) -> CGPoint {
        let radians = degrees * .pi / 180
        let dx = (point.x - center.x) * scale
        let dy = (point.y - center.y) * scale
        return CGPoint(
            x: center.x + dx * cos(radians) - dy * sin(radians),
            y: center.y + dx * sin(radians) + dy * cos(radians)
        )
    }
}
