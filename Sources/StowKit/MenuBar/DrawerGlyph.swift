import AppKit

/// The drawer icon (spec 5.1). Geometry comes from the approved mockup: a 16x14pt box,
/// y pointing down. `drawClosed(in:color:)` is shared with the app icon generator
/// (Sources/MakeIcon) so the geometry lives in one place.
public enum DrawerGlyph {
    public enum Variant: Equatable, Sendable {
        case closed
        case open(darkMenuBar: Bool)
        case unavailable
    }

    public static func image(_ variant: Variant) -> NSImage {
        switch variant {
        case .closed:
            return closedImage(alpha: 1)
        case .unavailable:
            return closedImage(alpha: 0.4)
        case .open(let dark):
            return openImage(body: dark ? Palette.amberOnDarkBar : Palette.amberOnLightBar,
                             handle: dark ? Palette.handleOnDarkBar : Palette.handleOnLightBar)
        }
    }

    /// Draws the closed drawer scaled into `rect`. The shape is vertically symmetric, so
    /// flipped and unflipped contexts draw it identically.
    public static func drawClosed(in rect: NSRect, color: NSColor) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: rect.minX, yBy: rect.minY)
        transform.scaleX(by: rect.width / 16, yBy: rect.height / 14)
        transform.concat()
        color.setStroke()
        let cabinet = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 1.7, width: 13, height: 10.6), xRadius: 2.4, yRadius: 2.4)
        cabinet.lineWidth = 1.4
        cabinet.stroke()
        stroke(from: NSPoint(x: 1.5, y: 7), to: NSPoint(x: 14.5, y: 7), width: 1.4, round: false)
        stroke(from: NSPoint(x: 6.6, y: 4.4), to: NSPoint(x: 9.4, y: 4.4), width: 1.5, round: true)
        stroke(from: NSPoint(x: 6.6, y: 9.6), to: NSPoint(x: 9.4, y: 9.6), width: 1.5, round: true)
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func closedImage(alpha: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: 16, height: 14), flipped: true) { rect in
            drawClosed(in: rect, color: NSColor.black.withAlphaComponent(alpha))
            return true
        }
        image.isTemplate = true   // the system tints it like every other menu bar icon
        return image
    }

    private static func openImage(body: RGB, handle: RGB) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 14), flipped: true) { _ in
            body.nsColor.setStroke()
            let cabinet = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 1.7, width: 11, height: 10.6), xRadius: 2.4, yRadius: 2.4)
            cabinet.lineWidth = 1.4
            cabinet.stroke()
            body.nsColor.setFill()
            NSBezierPath(roundedRect: NSRect(x: 5.5, y: 6.3, width: 11, height: 6), xRadius: 1.6, yRadius: 1.6).fill()
            handle.nsColor.setStroke()
            stroke(from: NSPoint(x: 9.6, y: 9.3), to: NSPoint(x: 12.4, y: 9.3), width: 1.4, round: true)
            return true
        }
        image.isTemplate = false   // amber is the "icons are showing" signal
        return image
    }

    private static func stroke(from start: NSPoint, to end: NSPoint, width: CGFloat, round: Bool) {
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        path.lineWidth = width
        if round { path.lineCapStyle = .round }
        path.stroke()
    }
}
