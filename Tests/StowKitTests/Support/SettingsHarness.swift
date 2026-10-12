import Foundation
@testable import StowKit

/// A SettingsModel over the HideController harness and fakes. Call `tearDown()` when done.
@MainActor final class SettingsHarness {
    let hide = Harness()
    let inventory = FakeInventory()
    let login = FakeLoginItem()
    let registrar = FakeRegistrar()
    let opened = Box<[URL]>([])
    let changes = Box(0)

    private(set) lazy var shortcuts = ShortcutController(registrar: registrar, preferences: hide.preferences, onPress: {})

    private(set) lazy var model: SettingsModel = {
        let opened = self.opened
        let changes = self.changes
        let model = SettingsModel(
            preferences: self.hide.preferences,
            hideController: self.hide.controller,
            inventory: self.inventory,
            loginItem: self.login,
            shortcuts: self.shortcuts,
            ownBundleID: StowKit.bundleIdentifier,
            runningBundleIDs: { [unowned self] in self.hide.running },
            isInstalled: { [unowned self] in self.hide.installed },
            openURL: { url in opened.value.append(url) })
        model.onChange = { changes.value += 1 }
        return model
    }()

    init() {
        inventory.found = [MenuBarApp(bundleID: "com.example.chat", name: "Chat"),
                           MenuBarApp(bundleID: "com.example.vpn", name: "VPN")]
    }

    func tearDown() { hide.tearDown() }
}
