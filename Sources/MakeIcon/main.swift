// Renders Resources/AppIcon.icns from DrawerGlyph, so the app icon and the menu bar icon
// share one geometry. A placeholder: replace the artwork any time.
// Usage: swift run MakeIcon Resources/AppIcon.icns
import AppKit
import StowKit

let output = CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.icns"
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Stow-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

/// The drawer in dark ink on an amber tile.
func renderIcon(pixels: Int) -> Data {
    let size = CGFloat(pixels)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let inset = size * 0.1
    let tile = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let shape = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.225, yRadius: tile.width * 0.225)
    NSGradient(starting: RGB(hex: 0xFFB340).nsColor, ending: RGB(hex: 0xFF7A1A).nsColor)!.draw(in: shape, angle: -90)
    let glyphWidth = tile.width * 0.56
    let glyphHeight = glyphWidth * 14 / 16
    let glyphRect = NSRect(x: tile.midX - glyphWidth / 2, y: tile.midY - glyphHeight / 2,
                           width: glyphWidth, height: glyphHeight)
    DrawerGlyph.drawClosed(in: glyphRect, color: RGB(hex: 0x2A1A05).nsColor)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try renderIcon(pixels: points * scale).write(to: iconset.appendingPathComponent(name))
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("iconutil failed with status \(iconutil.terminationStatus)\n".utf8))
    exit(1)
}
print("Wrote \(output)")
