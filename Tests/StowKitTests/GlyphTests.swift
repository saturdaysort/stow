import AppKit
import Testing
@testable import StowKit

@Suite @MainActor struct GlyphTests {
    @Test func contrastFormulaMatchesKnownValues() {
        #expect(abs(Contrast.ratio(RGB(hex: 0x000000), RGB(hex: 0xFFFFFF)) - 21) < 0.01)
        #expect(abs(Contrast.ratio(RGB(hex: 0xFFB340), RGB(hex: 0xFFFFFF)) - 1.78) < 0.01)
    }

    // Spec 7.1: fails if the ambers are ever changed to something illegible.
    @Test func ambersStayLegibleOnBothMenuBars() {
        #expect(Contrast.ratio(Palette.amberOnDarkBar, Palette.referenceDarkBar) >= 3)
        #expect(Contrast.ratio(Palette.amberOnLightBar, Palette.referenceLightBar) >= 3)
        #expect(Contrast.ratio(Palette.handleOnDarkBar, Palette.amberOnDarkBar) >= 3)
        #expect(Contrast.ratio(Palette.handleOnLightBar, Palette.amberOnLightBar) >= 3)
    }

    @Test func closedAndUnavailableAreTemplates() {
        let closed = DrawerGlyph.image(.closed)
        #expect(closed.isTemplate)
        #expect(closed.size == NSSize(width: 16, height: 14))
        #expect(DrawerGlyph.image(.unavailable).isTemplate)
    }

    @Test func openIsAmberAndNotATemplate() {
        let dark = DrawerGlyph.image(.open(darkMenuBar: true))
        #expect(!dark.isTemplate)
        #expect(dark.size == NSSize(width: 18, height: 14))
        // Measure, don't eyeball: sample the drawer front (pixel row 0 is the top row).
        #expect(pixel(dark, x: 14, y: 11).map { nearlyEqual($0, Palette.amberOnDarkBar) } == true)
        let light = DrawerGlyph.image(.open(darkMenuBar: false))
        #expect(pixel(light, x: 14, y: 11).map { nearlyEqual($0, Palette.amberOnLightBar) } == true)
    }

    private func pixel(_ image: NSImage, x: Int, y: Int) -> RGB? {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: Int(image.size.width), pixelsHigh: Int(image.size.height),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return nil }
        let red = UInt32((color.redComponent * 255).rounded())
        let green = UInt32((color.greenComponent * 255).rounded())
        let blue = UInt32((color.blueComponent * 255).rounded())
        return RGB(hex: red << 16 | green << 8 | blue)
    }

    private func nearlyEqual(_ a: RGB, _ b: RGB) -> Bool {
        abs(Int(a.red) - Int(b.red)) <= 4 && abs(Int(a.green) - Int(b.green)) <= 4 && abs(Int(a.blue) - Int(b.blue)) <= 4
    }
}
