import AppKit
import Testing
@testable import StowKit

// Review finding 4: spec 6.5 refreshes the list when Settings becomes key, and on app launch
// or quit while Settings is visible.
@Suite @MainActor struct SettingsWindowControllerTests {
    @Test func becomingKeyRefreshesTheList() async {
        let s = SettingsHarness(); defer { s.tearDown() }
        let controller = SettingsWindowController(model: s.model)
        let window = controller.makeWindowIfNeeded()
        let before = s.inventory.scans
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
        try? await Task.sleep(for: .milliseconds(200))
        #expect(s.inventory.scans == before + 1)
    }

    @Test func appChangesDoNotRefreshAHiddenWindow() async {
        let s = SettingsHarness(); defer { s.tearDown() }
        let controller = SettingsWindowController(model: s.model)
        _ = controller.makeWindowIfNeeded()   // created, never shown
        let before = s.inventory.scans
        controller.refreshIfVisible()
        try? await Task.sleep(for: .milliseconds(200))
        #expect(s.inventory.scans == before)
    }
}
