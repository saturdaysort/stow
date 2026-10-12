import Foundation
@testable import StowKit

/// A HideController wired to fakes, with knobs for running apps, install location and busyness.
/// Call `tearDown()` at the end of each test (use `defer`).
@MainActor final class Harness {
    let restriction = FakeRestriction()
    let scheduler = ManualScheduler()
    let preferences: Preferences
    var running = ["com.apple.finder", "com.example.chat", "com.example.vpn", StowKit.bundleIdentifier]
    var installed = true
    var busy = false
    private let cleanup: () -> Void

    private(set) lazy var controller = HideController(
        restriction: restriction,
        preferences: preferences,
        scheduler: scheduler,
        runningBundleIDs: { [unowned self] in self.running },
        isInstalledCorrectly: { [unowned self] in self.installed },
        isBusy: { [unowned self] in self.busy },
        ownBundleID: StowKit.bundleIdentifier)

    init(hidden: [String] = ["com.example.vpn"]) {
        let (defaults, cleanup) = TestDefaults.make()
        self.cleanup = cleanup
        preferences = Preferences(defaults: defaults)
        preferences.hiddenBundleIDs = hidden
    }

    func tearDown() { cleanup() }
}
