import AppKit

enum Variant: String, CaseIterable {
    case release = "AppIcon"
    case development = "AppIconDev"
}

struct Palette {
    let background: CGColor
    let star: CGColor
    let halo: CGColor
    let head: CGColor
    let tail: CGColor
    let sideTail: CGColor
}

func srgb(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func palette(for variant: Variant) -> Palette {
    switch variant {
    case .release:
        return Palette(
            background: srgb(0x111733),
            star: srgb(0xFFFFFF, alpha: 0.55),
            halo: srgb(0xFF8A3D, alpha: 0.2),
            head: srgb(0xFFF6E8),
            tail: srgb(0xFF8A3D),
            sideTail: srgb(0xFFB870)
        )
    case .development:
        return Palette(
            background: srgb(0x23262B),
            star: srgb(0xFFFFFF, alpha: 0.4),
            halo: srgb(0x35C08A, alpha: 0.2),
            head: srgb(0xF2FFF8),
            tail: srgb(0x35C08A),
            sideTail: srgb(0x8BDDB8)
        )
    }
}

let stars: [(CGPoint, CGFloat)] = [
    (CGPoint(x: 182, y: 842), 9),
    (CGPoint(x: 318, y: 742), 6),
    (CGPoint(x: 846, y: 312), 8),
    (CGPoint(x: 902, y: 846), 6),
    (CGPoint(x: 492, y: 912), 5),
    (CGPoint(x: 744, y: 158), 5),
    (CGPoint(x: 112, y: 512), 5),
]

func rotated(_ point: CGPoint, around center: CGPoint, degrees: CGFloat, scale: CGFloat) -> CGPoint {
    let radians = degrees * .pi / 180
    let dx = (point.x - center.x) * scale
    let dy = (point.y - center.y) * scale
    return CGPoint(
        x: center.x + dx * cos(radians) - dy * sin(radians),
        y: center.y + dx * sin(radians) + dy * cos(radians)
    )
}

func fillStreak(_ context: CGContext, from head: CGPoint, to tip: CGPoint, halfWidth: CGFloat, color: CGColor) {
    let dx = tip.x - head.x
    let dy = tip.y - head.y
    let length = (dx * dx + dy * dy).squareRoot()
    let offsetX = -dy / length * halfWidth
    let offsetY = dx / length * halfWidth
    let bend = CGPoint(x: (head.x + tip.x) / 2 + offsetY * 0.35, y: (head.y + tip.y) / 2 - offsetX * 0.35)
    context.beginPath()
    context.move(to: CGPoint(x: head.x + offsetX, y: head.y + offsetY))
    context.addQuadCurve(to: tip, control: CGPoint(x: bend.x + offsetX * 0.5, y: bend.y + offsetY * 0.5))
    context.addQuadCurve(to: CGPoint(x: head.x - offsetX, y: head.y - offsetY), control: CGPoint(x: bend.x - offsetX * 0.5, y: bend.y - offsetY * 0.5))
    context.closePath()
    context.setFillColor(color)
    context.fillPath()
}

func fillCircle(_ context: CGContext, center: CGPoint, radius: CGFloat, color: CGColor) {
    context.setFillColor(color)
    context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
}

func drawDevelopmentBand(_ context: CGContext, color: CGColor) {
    context.setFillColor(color)
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 190))
    let text = NSAttributedString(
        string: "DEV",
        attributes: [
            .font: NSFont.systemFont(ofSize: 132, weight: .heavy),
            .foregroundColor: NSColor.white,
            .kern: 18,
        ]
    )
    let size = text.size()
    text.draw(at: NSPoint(x: (1024 - size.width) / 2, y: (190 - size.height) / 2 + 6))
}

func drawIcon(_ context: CGContext, variant: Variant) {
    let colors = palette(for: variant)
    context.setFillColor(colors.background)
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    for (center, radius) in stars {
        fillCircle(context, center: center, radius: radius, color: colors.star)
    }
    let head = CGPoint(x: 650, y: 650)
    let tip = CGPoint(x: 168, y: 168)
    fillCircle(context, center: head, radius: 168, color: colors.halo)
    fillStreak(context, from: head, to: rotated(tip, around: head, degrees: 17, scale: 0.72), halfWidth: 58, color: colors.sideTail)
    fillStreak(context, from: head, to: rotated(tip, around: head, degrees: -17, scale: 0.72), halfWidth: 58, color: colors.sideTail)
    fillStreak(context, from: head, to: tip, halfWidth: 112, color: colors.tail)
    fillCircle(context, center: head, radius: 118, color: colors.head)
    if variant == .development {
        drawDevelopmentBand(context, color: colors.tail)
    }
}

func renderPNG(pixels: Int, variant: Variant) -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("cannot create bitmap")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon(context, variant: variant)
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("cannot encode png")
    }
    return data
}

let iconSlots: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
]

func writeIconSet(variant: Variant, catalog: URL) throws {
    let folder = catalog.appending(path: "\(variant.rawValue).appiconset", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    var images: [[String: String]] = []
    for slot in iconSlots {
        let suffix = slot.scale == 1 ? "" : "@\(slot.scale)x"
        let filename = "icon_\(slot.points)x\(slot.points)\(suffix).png"
        try renderPNG(pixels: slot.points * slot.scale, variant: variant).write(to: folder.appending(path: filename))
        images.append([
            "filename": filename,
            "idiom": "mac",
            "scale": "\(slot.scale)x",
            "size": "\(slot.points)x\(slot.points)",
        ])
    }
    let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
    let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try json.write(to: folder.appending(path: "Contents.json"))
}

let arguments = CommandLine.arguments
if arguments.count == 3 && arguments[1] == "--preview" {
    let folder = URL(filePath: arguments[2], directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for variant in Variant.allCases {
        try renderPNG(pixels: 1024, variant: variant).write(to: folder.appending(path: "\(variant.rawValue).png"))
    }
} else if arguments.count == 2 {
    let catalog = URL(filePath: arguments[1], directoryHint: .isDirectory)
    for variant in Variant.allCases {
        try writeIconSet(variant: variant, catalog: catalog)
    }
} else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <Assets.xcassets> | --preview <folder>\n".utf8))
    exit(2)
}
