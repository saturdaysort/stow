import AppKit
import SwiftUI

/// Hosts SettingsView in a standard window. Stow has no Dock icon, so showing the window
/// also activates the app.
@MainActor public final class SettingsWindowController {
    private let model: SettingsModel
    private var window: NSWindow?

    public init(model: SettingsModel) {
        self.model = model
    }

    public func show() {
        let reopening = window != nil
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            window.title = "Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        if reopening {
            Task { await model.refresh() }   // a new window refreshes from the view's .task
        }
    }
}
