import CoreGraphics
import Testing
@testable import StowKit

@Suite struct BusyProbeTests {
    // The two displays measured on 2026-10-12 (global Cocoa coordinates).
    let builtIn = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1800, height: 1169),
                                 visibleFrame: CGRect(x: 0, y: 0, width: 1800, height: 1130))
    let studio = ScreenGeometry(frame: CGRect(x: 1800, y: 0, width: 2880, height: 1620),
                                visibleFrame: CGRect(x: 1800, y: 0, width: 2880, height: 1590))

    @Test func stripMatchesTheMenuBarHeight() {
        #expect(MenuBarBusyProbe.menuBarStrip(of: builtIn) == CGRect(x: 0, y: 1130, width: 1800, height: 39))
    }

    @Test func pointerInEitherMenuBarIsBusy() {
        #expect(MenuBarBusyProbe.pointerInMenuBar(CGPoint(x: 1500, y: 1150), screens: [builtIn, studio]))
        #expect(MenuBarBusyProbe.pointerInMenuBar(CGPoint(x: 3000, y: 1600), screens: [builtIn, studio]))
        #expect(MenuBarBusyProbe.pointerInMenuBar(CGPoint(x: 1500, y: 1169), screens: [builtIn, studio]))  // top edge
    }

    @Test func pointerBelowTheMenuBarIsNotBusy() {
        #expect(!MenuBarBusyProbe.pointerInMenuBar(CGPoint(x: 1500, y: 1100), screens: [builtIn, studio]))
        #expect(!MenuBarBusyProbe.pointerInMenuBar(CGPoint(x: 3000, y: 1500), screens: [builtIn, studio]))
    }

    @Test func autoHiddenMenuBarFallsBackTo24Points() {
        let autoHidden = ScreenGeometry(frame: builtIn.frame, visibleFrame: builtIn.frame)
        #expect(MenuBarBusyProbe.menuBarStrip(of: autoHidden).height == 24)
        #expect(MenuBarBusyProbe.pointerInMenuBar(CGPoint(x: 10, y: 1150), screens: [autoHidden]))
        #expect(!MenuBarBusyProbe.pointerInMenuBar(CGPoint(x: 10, y: 1140), screens: [autoHidden]))
    }

    @Test func popUpMenuCheckRuns() {
        // Smoke test only. On-device check 6 confirms this never triggers a Screen Recording request.
        _ = MenuBarBusyProbe.popUpMenuIsOpen()
    }
}
