import AppKit

enum Variant: String, CaseIterable {
    case release = "AppIcon"
    case development = "AppIconDev"
}

let symbolName = "arrow.triangle.branch"

struct Palette {
    let background: CGColor
    let band: CGColor
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
        return Palette(background: srgb(0x2F6FED), band: srgb(0x1D4FB8))
    case .development:
        return Palette(background: srgb(0x2E9E6E), band: srgb(0x1F7451))
    }
}

func drawSymbol(centeredAt center: CGPoint, pointSize: CGFloat) {
    let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration) else {
        fatalError("missing symbol \(symbolName)")
    }
    let size = symbol.size
    symbol.draw(in: NSRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height))
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
    if variant == .development {
        drawSymbol(centeredAt: CGPoint(x: 512, y: 600), pointSize: 420)
        drawDevelopmentBand(context, color: colors.band)
    } else {
        drawSymbol(centeredAt: CGPoint(x: 512, y: 512), pointSize: 480)
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
