import AppKit

/// An sRGB color with WCAG relative luminance, so contrast can be checked in tests.
public struct RGB: Equatable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(hex: UInt32) {
        red = UInt8((hex >> 16) & 0xFF)
        green = UInt8((hex >> 8) & 0xFF)
        blue = UInt8(hex & 0xFF)
    }

    public var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
    }

    /// WCAG 2.x relative luminance.
    public var relativeLuminance: Double {
        func channel(_ value: UInt8) -> Double {
            let c = Double(value) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }
}

public enum Contrast {
    /// WCAG contrast ratio: 1 means none, 21 is black on white.
    public static func ratio(_ a: RGB, _ b: RGB) -> Double {
        let high = max(a.relativeLuminance, b.relativeLuminance)
        let low = min(a.relativeLuminance, b.relativeLuminance)
        return (high + 0.05) / (low + 0.05)
    }
}

/// The drawer's amber, by menu bar appearance (spec 5.1). The bright amber measures only
/// 1.47:1 on a light menu bar, so light bars get a deeper shade (4.52:1).
public enum Palette {
    public static let amberOnDarkBar = RGB(hex: 0xFFB340)
    public static let amberOnLightBar = RGB(hex: 0xA35400)
    public static let handleOnDarkBar = RGB(hex: 0x17130E)
    public static let handleOnLightBar = RGB(hex: 0xFFFFFF)
    /// Reference menu bar backgrounds the contrast test measures against.
    public static let referenceDarkBar = RGB(hex: 0x1E1E1E)
    public static let referenceLightBar = RGB(hex: 0xE6E9F0)
}
