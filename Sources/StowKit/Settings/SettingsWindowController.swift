import AppKit
import SwiftUI

/// Hosts SettingsView in a standard window. Stow has no Dock icon, so showing the window
/// also activates the app.
///
/// The list refreshes when the window becomes key (opening, reopening, coming back from
/// System Settings) and when apps launch or quit while it's visible (spec 6.5).
@MainActor public final class SettingsWindowController {
    private let model: SettingsModel
    private var window: NSWindow?
    private var keyObserver: (any NSObjectProtocol)?

    public init(model: SettingsModel) {
        self.model = model
    }

    public func show() {
        let window = makeWindowIfNeeded()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)   // becoming key triggers the refresh
    }

    /// Called when an app launches or quits: refresh only while Settings is on screen.
    public func refreshIfVisible() {
        if window?.isVisible == true { refresh() }
    }

    @discardableResult
    func makeWindowIfNeeded() -> NSWindow {
        if let window { return window }
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
        window.title = "Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        keyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        self.window = window
        return window
    }

    private func refresh() {
        Task { await model.refresh() }
    }
}
