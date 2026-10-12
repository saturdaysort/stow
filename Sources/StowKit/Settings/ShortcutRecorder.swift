import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A field that records the next key combination (spec 6.6). Click it, then press keys.
/// Esc cancels; Delete clears it (no shortcut). Needs at least one of Control, Option or Command.
struct ShortcutRecorder: NSViewRepresentable {
    var shortcut: Shortcut?
    var onChange: @MainActor (Shortcut?) -> Void

    func makeNSView(context: Context) -> RecorderField {
        let field = RecorderField()
        field.shortcut = shortcut
        field.onChange = onChange
        return field
    }

    func updateNSView(_ field: RecorderField, context: Context) {
        field.onChange = onChange
        if !field.isRecording { field.shortcut = shortcut }
    }
}

final class RecorderField: NSView {
    var shortcut: Shortcut? { didSet { needsDisplay = true } }
    var onChange: (@MainActor (Shortcut?) -> Void)?
    /// Played when a combination has no Control, Option or Command. Tests replace it.
    var beep: @MainActor () -> Void = { NSSound.beep() }
    private(set) var isRecording = false { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 140, height: 22) }

    func beginRecording() { isRecording = true }

    override func mouseDown(with event: NSEvent) {
        beginRecording()
        window?.makeFirstResponder(self)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return super.keyDown(with: event) }
        switch Int(event.keyCode) {
        case kVK_Escape:
            isRecording = false
        case kVK_Delete, kVK_ForwardDelete:
            isRecording = false
            shortcut = nil
            onChange?(nil)
        default:
            guard let recorded = Shortcut.from(keyCode: event.keyCode, flags: event.modifierFlags) else {
                beep()
                return
            }
            isRecording = false
            shortcut = recorded
            onChange?(recorded)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.15) : NSColor.quaternaryLabelColor).setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = 1
        path.stroke()
        let text = isRecording ? "Type shortcut…" : (shortcut?.displayString() ?? "None")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: (isRecording || shortcut == nil) ? NSColor.secondaryLabelColor : NSColor.labelColor,
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
                  withAttributes: attributes)
    }

    // VoiceOver: a button that starts recording.
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityLabel() -> String? {
        "Keyboard shortcut: " + (shortcut?.displayString() ?? "None")
    }
    override func accessibilityPerformPress() -> Bool {
        beginRecording()
        window?.makeFirstResponder(self)
        return true
    }
}
