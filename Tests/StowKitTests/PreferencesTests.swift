import Foundation
import Testing
@testable import StowKit

@Suite @MainActor struct PreferencesTests {
    @Test func defaults() {
        let (defaults, cleanup) = TestDefaults.make(); defer { cleanup() }
        let prefs = Preferences(defaults: defaults)
        #expect(prefs.hiddenBundleIDs.isEmpty)
        #expect(prefs.rehideDelay == .tenSeconds)
        #expect(prefs.shortcut == .defaultShortcut)
        #expect(prefs.hasCompletedFirstRun == false)
    }

    @Test func valuesSurviveARelaunch() {
        let (defaults, cleanup) = TestDefaults.make(); defer { cleanup() }
        let first = Preferences(defaults: defaults)
        first.hiddenBundleIDs = ["com.example.vpn", "com.adobe.acc.AdobeCreativeCloud"]
        first.rehideDelay = .thirtySeconds
        first.shortcut = Shortcut(keyCode: 3, modifiers: 256)
        first.hasCompletedFirstRun = true
        let second = Preferences(defaults: defaults)
        #expect(second.hiddenBundleIDs == ["com.adobe.acc.AdobeCreativeCloud", "com.example.vpn"])
        #expect(second.rehideDelay == .thirtySeconds)
        #expect(second.shortcut == Shortcut(keyCode: 3, modifiers: 256))
        #expect(second.hasCompletedFirstRun)
    }

    @Test func clearedShortcutStaysCleared() {
        let (defaults, cleanup) = TestDefaults.make(); defer { cleanup() }
        let prefs = Preferences(defaults: defaults)
        prefs.shortcut = nil
        #expect(Preferences(defaults: defaults).shortcut == nil)
    }

    @Test func setHiddenAddsRemovesAndDedupes() {
        let (defaults, cleanup) = TestDefaults.make(); defer { cleanup() }
        let prefs = Preferences(defaults: defaults)
        prefs.setHidden("com.example.chat", true)
        prefs.setHidden("com.example.chat", true)
        prefs.setHidden("com.example.vpn", true)
        #expect(prefs.hiddenBundleIDs == ["com.example.chat", "com.example.vpn"])
        prefs.setHidden("com.example.chat", false)
        #expect(prefs.hiddenBundleIDs == ["com.example.vpn"])
        #expect(prefs.isHidden("com.example.vpn"))
        #expect(!prefs.isHidden("com.example.chat"))
    }

    // Review Focus 4: hand-edited or damaged values fall back instead of crashing.
    @Test func delaysClampToNearest() {
        #expect(RehideDelay.nearest(to: -3) == .never)
        #expect(RehideDelay.nearest(to: 0) == .never)
        #expect(RehideDelay.nearest(to: 1) == .fiveSeconds)
        #expect(RehideDelay.nearest(to: 7) == .fiveSeconds)
        #expect(RehideDelay.nearest(to: 8) == .tenSeconds)
        #expect(RehideDelay.nearest(to: 20) == .tenSeconds)     // tie goes to the shorter delay
        #expect(RehideDelay.nearest(to: 45) == .thirtySeconds)  // tie goes to the shorter delay
        #expect(RehideDelay.nearest(to: 999) == .oneMinute)
    }

    @Test func corruptedValuesFallBack() {
        let (defaults, cleanup) = TestDefaults.make(); defer { cleanup() }
        defaults.set("not a list", forKey: "hiddenBundleIDs")
        defaults.set("ten", forKey: "rehideDelaySeconds")
        defaults.set("x", forKey: "shortcutKeyCode")
        let prefs = Preferences(defaults: defaults)
        #expect(prefs.hiddenBundleIDs.isEmpty)
        #expect(prefs.rehideDelay == .tenSeconds)
        #expect(prefs.shortcut == .defaultShortcut)

        defaults.set([1, "com.example.vpn", "", "com.example.vpn"] as [Any], forKey: "hiddenBundleIDs")
        defaults.set(7, forKey: "rehideDelaySeconds")
        defaults.set(4, forKey: "shortcutKeyCode")
        defaults.set(512, forKey: "shortcutModifiers")   // shift only: not a usable shortcut
        #expect(prefs.hiddenBundleIDs == ["com.example.vpn"])
        #expect(prefs.rehideDelay == .fiveSeconds)
        #expect(prefs.shortcut == .defaultShortcut)
    }

    @Test func delayTitles() {
        #expect(RehideDelay.allCases.map(\.title) == ["Never", "5 seconds", "10 seconds", "30 seconds", "1 minute"])
        #expect(RehideDelay.never.seconds == nil)
        #expect(RehideDelay.tenSeconds.seconds == 10)
    }
}
