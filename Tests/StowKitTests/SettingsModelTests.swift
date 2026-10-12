import Foundation
import Testing
@testable import StowKit

@Suite @MainActor struct SettingsModelTests {
    @Test func refreshBuildsTheList() async {
        let s = SettingsHarness(); defer { s.tearDown() }
        await s.model.refresh()
        #expect(s.model.apps == [
            ListedApp(bundleID: "com.example.chat", name: "Chat", isRunning: true, isHidden: false),
            ListedApp(bundleID: "com.example.vpn", name: "VPN", isRunning: true, isHidden: true),
        ])
        #expect(s.model.isTrusted)
        #expect(s.model.rehideDelay == .tenSeconds)
        #expect(s.model.shortcut == .defaultShortcut)
    }

    @Test func switchingAnAppOnHidesItRightAway() async {
        let s = SettingsHarness(); defer { s.tearDown() }
        s.hide.controller.start()
        await s.model.refresh()
        let chat = s.model.apps[0]
        s.model.setHidden(chat, true)
        #expect(s.hide.preferences.hiddenBundleIDs == ["com.example.chat", "com.example.vpn"])
        #expect(s.hide.restriction.activations.last == ["com.apple.finder", "studio.longbrook.stow"])
        #expect(s.model.apps[0].isHidden)
        #expect(s.changes.value == 1)
    }

    @Test func withoutAccessibilityHiddenAppsStillShow() async {
        let s = SettingsHarness(); defer { s.tearDown() }
        s.inventory.isTrusted = false
        s.inventory.names = ["com.example.vpn": "VPN"]
        await s.model.refresh()
        #expect(!s.model.isTrusted)
        #expect(s.model.apps == [ListedApp(bundleID: "com.example.vpn", name: "VPN", isRunning: true, isHidden: true)])
    }

    @Test func pollingFillsTheListOnceAccessIsGranted() async {
        let s = SettingsHarness(); defer { s.tearDown() }
        s.inventory.isTrusted = false
        await s.model.refresh()
        #expect(await s.model.pollTrust() == false)
        s.inventory.isTrusted = true
        #expect(await s.model.pollTrust() == true)
        #expect(s.model.apps.count == 2)
        #expect(s.model.isTrusted)
    }

    @Test func loginSwitchShowsTheRealState() {
        let s = SettingsHarness(); defer { s.tearDown() }
        s.model.setLoginEnabled(true)
        #expect(s.model.loginStatus == .enabled)
        s.login.failNextChange = true
        s.model.setLoginEnabled(false)
        #expect(s.model.loginStatus == .enabled)
    }

    @Test func shortcutConflictShowsTheMessageAndKeepsTheOldOne() {
        let s = SettingsHarness(); defer { s.tearDown() }
        s.shortcuts.start()
        let taken = Shortcut(keyCode: 3, modifiers: 256)
        s.registrar.taken = [taken]
        s.model.setShortcut(taken)
        #expect(s.model.shortcutError == "That shortcut is used by another app")
        #expect(s.model.shortcut == .defaultShortcut)
    }

    @Test func delayIsSaved() {
        let s = SettingsHarness(); defer { s.tearDown() }
        s.model.setRehideDelay(.oneMinute)
        #expect(s.hide.preferences.rehideDelay == .oneMinute)
        #expect(s.model.rehideDelay == .oneMinute)
    }

    @Test func menuBarSettingsLinkOpensTheMenuBarPane() {
        let s = SettingsHarness(); defer { s.tearDown() }
        s.model.openMenuBarSettings()
        #expect(s.opened.value == [URL(string: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension")!])
    }

    @Test func installLocationIsReported() async {
        let s = SettingsHarness(); defer { s.tearDown() }
        s.hide.installed = false
        await s.model.refresh()
        #expect(!s.model.isInstalledCorrectly)
    }
}
