import AppKit
import Carbon.HIToolbox
import SwiftUI
import Testing
@testable import StowKit

@Suite @MainActor struct SettingsViewTests {
    @Test func settingsViewLaysOut() async {
        let s = SettingsHarness(); defer { s.tearDown() }
        await s.model.refresh()
        let view = NSHostingView(rootView: SettingsView(model: s.model))
        view.frame = NSRect(x: 0, y: 0, width: 440, height: 620)
        view.layoutSubtreeIfNeeded()
        #expect(view.fittingSize.width >= 400)
    }

    @Test func recorderRecordsAShortcut() {
        let field = RecorderField()
        let recorded = Box<Shortcut?>(nil)
        field.onChange = { recorded.value = $0 }
        field.beginRecording()
        field.keyDown(with: keyEvent(code: UInt16(kVK_ANSI_K), flags: [.control, .option]))
        #expect(recorded.value == Shortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: 6144))
        #expect(!field.isRecording)
    }

    @Test func recorderEscapeCancelsAndDeleteClears() {
        let field = RecorderField()
        field.shortcut = .defaultShortcut
        let calls = Box<[Shortcut?]>([])
        field.onChange = { calls.value.append($0) }
        field.beginRecording()
        field.keyDown(with: keyEvent(code: UInt16(kVK_Escape), flags: []))
        #expect(calls.value.isEmpty)
        #expect(field.shortcut == .defaultShortcut)
        field.beginRecording()
        field.keyDown(with: keyEvent(code: UInt16(kVK_Delete), flags: []))
        #expect(calls.value == [nil])
        #expect(field.shortcut == nil)
    }

    @Test func recorderRejectsShiftOnlyCombinations() {
        let field = RecorderField()
        let calls = Box(0)
        let beeps = Box(0)
        field.onChange = { _ in calls.value += 1 }
        field.beep = { beeps.value += 1 }
        field.beginRecording()
        field.keyDown(with: keyEvent(code: UInt16(kVK_ANSI_K), flags: [.shift]))
        #expect(calls.value == 0)
        #expect(beeps.value == 1)
        #expect(field.isRecording)
    }

    private func keyEvent(code: UInt16, flags: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                         context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false,
                         keyCode: code)!
    }
}
