import AppKit
import Testing
@testable import StowKit

@Suite @MainActor struct MenuModelTests {
    @Test func hidden() {
        #expect(MenuModel.make(state: .hidden(count: 5), hiddenCount: 5) == MenuModel(
            toggleTitle: "Show Hidden Icons", toggleEnabled: true,
            statusLine: "Hiding 5 apps", accessibilityLabel: "Stow, 5 apps hidden"))
        #expect(MenuModel.make(state: .hidden(count: 1), hiddenCount: 1).statusLine == "Hiding 1 app")
    }

    @Test func shownWithAndWithoutApps() {
        let ready = MenuModel.make(state: .shown, hiddenCount: 3)
        #expect(ready.toggleTitle == "Hide Icons")
        #expect(ready.toggleEnabled)
        #expect(ready.statusLine == "All icons showing")
        #expect(ready.accessibilityLabel == "Stow, icons showing")
        let empty = MenuModel.make(state: .shown, hiddenCount: 0)
        #expect(!empty.toggleEnabled)
        #expect(empty.statusLine == "Pick apps to hide in Settings")
    }

    @Test func unavailableReasons() {
        #expect(MenuModel.make(state: .unavailable(.notInApplications), hiddenCount: 2).statusLine
                == "Move Stow to Applications to hide icons")
        #expect(MenuModel.make(state: .unavailable(.frameworkMissing), hiddenCount: 2).statusLine
                == "Hiding isn't available on this version of macOS")
        let refused = MenuModel.make(state: .unavailable(.activationFailed("refused")), hiddenCount: 2)
        #expect(refused.statusLine == "Hiding unavailable: refused")
        #expect(!refused.toggleEnabled)
        #expect(refused.accessibilityLabel == "Stow, hiding unavailable")
    }

    @Test func keyEquivalentOnlyForLetterAndDigitShortcuts() {
        let hint = MenuModel.keyEquivalent(for: .defaultShortcut, translate: { _ in nil })
        #expect(hint?.key == "h")
        #expect(hint?.modifiers == [.control, .option])
        #expect(MenuModel.keyEquivalent(for: Shortcut(keyCode: 0x60, modifiers: 256), translate: { _ in nil }) == nil)  // F5
        #expect(MenuModel.keyEquivalent(for: nil) == nil)
    }

    @Test func iconFollowsStateAndMenuBarAppearance() {
        let dark = NSAppearance(named: .darkAqua)!
        let light = NSAppearance(named: .aqua)!
        #expect(StatusItemController.variant(for: .hidden(count: 2), appearance: dark) == .closed)
        #expect(StatusItemController.variant(for: .shown, appearance: dark) == .open(darkMenuBar: true))
        #expect(StatusItemController.variant(for: .shown, appearance: light) == .open(darkMenuBar: false))
        #expect(StatusItemController.variant(for: .unavailable(.frameworkMissing), appearance: light) == .unavailable)
    }
}
