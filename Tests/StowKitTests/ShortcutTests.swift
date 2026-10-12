import AppKit
import Carbon.HIToolbox
import Testing
@testable import StowKit

@Suite @MainActor struct ShortcutTests {
    /// Stands in for "the keyboard layout couldn't be read", so tests don't depend on Nate's layout.
    private static func noLayout(_ keyCode: UInt32) -> String? { nil }

    @Test func defaultIsControlOptionH() {
        #expect(Shortcut.defaultShortcut == Shortcut(keyCode: 4, modifiers: 6144))
        #expect(Shortcut.defaultShortcut.displayString(translate: Self.noLayout) == "⌃⌥H")
    }

    @Test func buildsFromEventFlags() {
        #expect(Shortcut.from(keyCode: 4, flags: [.control, .option]) == .defaultShortcut)
        #expect(Shortcut.from(keyCode: 4, flags: [.command, .shift]) == Shortcut(keyCode: 4, modifiers: 768))
    }

    @Test func rejectsShiftOnlyOrNoModifiers() {
        #expect(Shortcut.from(keyCode: 4, flags: [.shift]) == nil)
        #expect(Shortcut.from(keyCode: 4, flags: []) == nil)
        #expect(!Shortcut(keyCode: 4, modifiers: 512).isValid)
    }

    @Test func modifierOrderIsControlOptionShiftCommand() {
        let all = Shortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: 4096 | 2048 | 512 | 256)
        #expect(all.displayString(translate: Self.noLayout) == "⌃⌥⇧⌘K")
    }

    @Test func specialKeysUseTheirSymbols() {
        #expect(Shortcut(keyCode: UInt32(kVK_F5), modifiers: 256).displayString(translate: Self.noLayout) == "⌘F5")
        #expect(Shortcut(keyCode: UInt32(kVK_RightArrow), modifiers: 6144).displayString(translate: Self.noLayout) == "⌃⌥→")
        #expect(Shortcut(keyCode: UInt32(kVK_Space), modifiers: 4096).displayString(translate: Self.noLayout) == "⌃Space")
    }

    @Test func layoutCharacterWinsOverTheANSITable() {
        let german: @MainActor (UInt32) -> String? = { $0 == UInt32(kVK_ANSI_Semicolon) ? "Ö" : nil }
        #expect(Shortcut(keyCode: UInt32(kVK_ANSI_Semicolon), modifiers: 4096).displayString(translate: german) == "⌃Ö")
    }

    @Test func unknownKeyCodeStillDisplays() {
        #expect(KeyNames.name(for: 0x7F, translate: Self.noLayout) == "Key 127")
    }
}
