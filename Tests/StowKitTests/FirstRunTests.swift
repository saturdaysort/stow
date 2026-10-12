import Testing
@testable import StowKit

@Suite @MainActor struct FirstRunTests {
    @Test func firstRunUntilMarkedDone() {
        let (defaults, cleanup) = TestDefaults.make(); defer { cleanup() }
        let prefs = Preferences(defaults: defaults)
        #expect(FirstRun.isNeeded(prefs))
        prefs.hasCompletedFirstRun = true
        #expect(!FirstRun.isNeeded(prefs))
    }
}
