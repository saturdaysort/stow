import AppKit

/// A screen's geometry in global Cocoa coordinates (origin bottom-left).
public struct ScreenGeometry: Equatable, Sendable {
    public var frame: CGRect
    public var visibleFrame: CGRect

    public init(frame: CGRect, visibleFrame: CGRect) {
        self.frame = frame
        self.visibleFrame = visibleFrame
    }
}

/// "Busy" means: don't auto-hide right now (spec 4.5). It uses only the pointer position
/// and window layers, and neither needs Screen Recording permission.
public enum MenuBarBusyProbe {
    /// The menu bar strip at the top of a screen. Falls back to 24pt when the menu bar
    /// auto-hides and the screen has no top inset.
    public static func menuBarStrip(of screen: ScreenGeometry) -> CGRect {
        let inset = screen.frame.maxY - screen.visibleFrame.maxY
        let height = inset > 0 ? inset : 24
        return CGRect(x: screen.frame.minX, y: screen.frame.maxY - height, width: screen.frame.width, height: height)
    }

    /// Inclusive of the very top edge, where the pointer sits when pushed against it.
    public static func pointerInMenuBar(_ point: CGPoint, screens: [ScreenGeometry]) -> Bool {
        screens.contains { screen in
            let strip = menuBarStrip(of: screen)
            return point.x >= strip.minX && point.x < strip.maxX && point.y >= strip.minY && point.y <= strip.maxY
        }
    }

    /// True when any app has a pop-up menu on screen. Reads window layers only.
    public static func popUpMenuIsOpen() -> Bool {
        let level = Int(CGWindowLevelForKey(.popUpMenuWindow))
        let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.contains { ($0[kCGWindowLayer as String] as? Int) == level }
    }

    @MainActor
    public static func isBusy() -> Bool {
        let screens = NSScreen.screens.map { ScreenGeometry(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        return pointerInMenuBar(NSEvent.mouseLocation, screens: screens) || popUpMenuIsOpen()
    }
}
