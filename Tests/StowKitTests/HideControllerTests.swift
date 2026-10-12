import Testing
@testable import StowKit

@Suite @MainActor struct HideControllerTests {
    @Test func startHidesChosenApps() {
        let h = Harness(); defer { h.tearDown() }
        h.controller.start()
        #expect(h.restriction.activations == [["com.apple.finder", "com.example.chat", "studio.longbrook.stow"]])
        #expect(h.restriction.lastSystemItems == Array(0..<64))
        #expect(h.controller.state == .hidden(count: 1))
    }

    @Test func startStaysShownWithNothingToHide() {
        let h = Harness(hidden: []); defer { h.tearDown() }
        h.controller.start()
        #expect(h.restriction.events.isEmpty)
        #expect(h.controller.state == .shown)
    }

    @Test func toggleShowsAndReleasesTheAssertion() {
        let h = Harness(); defer { h.tearDown() }
        h.controller.start()
        h.controller.toggle()
        #expect(h.controller.state == .shown)
        #expect(h.restriction.events.last == .invalidate(1))
        #expect(h.restriction.liveTokens.isEmpty)
    }

    @Test func toggleFromShownHidesAgain() {
        let h = Harness(); defer { h.tearDown() }
        h.controller.start()
        h.controller.toggle()
        h.controller.toggle()
        #expect(h.controller.state == .hidden(count: 1))
        #expect(h.restriction.liveTokens.count == 1)
    }

    @Test func stowIsAlwaysAllowedEvenIfListedAsHidden() {
        let h = Harness(hidden: [StowKit.bundleIdentifier, "com.example.vpn"]); defer { h.tearDown() }
        h.controller.start()
        #expect(h.restriction.activations.last?.contains(StowKit.bundleIdentifier) == true)
    }

    @Test func refusalFailsSafeToUnavailable() {
        let h = Harness(); defer { h.tearDown() }
        h.restriction.refuse = true
        h.controller.start()
        #expect(h.controller.state == .unavailable(.activationFailed("refused")))
        #expect(h.restriction.liveTokens.isEmpty)
    }

    @Test func toggleFromUnavailableRetries() {
        let h = Harness(); defer { h.tearDown() }
        h.restriction.refuse = true
        h.controller.start()
        h.restriction.refuse = false
        h.controller.toggle()
        #expect(h.controller.state == .hidden(count: 1))
    }

    @Test func outsideApplicationsNeverActivates() {
        let h = Harness(); defer { h.tearDown() }
        h.installed = false
        h.controller.start()
        #expect(h.controller.state == .unavailable(.notInApplications))
        #expect(h.restriction.events.isEmpty)
    }

    @Test func missingFrameworkIsUnavailable() {
        let h = Harness(); defer { h.tearDown() }
        h.restriction.isAvailable = false
        h.controller.start()
        #expect(h.controller.state == .unavailable(.frameworkMissing))
        #expect(h.restriction.events.isEmpty)
    }

    @Test func quitReleasesTheAssertion() {
        let h = Harness(); defer { h.tearDown() }
        h.controller.start()
        h.controller.prepareForQuit()
        #expect(h.restriction.liveTokens.isEmpty)
    }

    @Test func stateChangesAreReported() {
        let h = Harness(); defer { h.tearDown() }
        var seen: [HideState] = []
        h.controller.onStateChange = { seen.append($0) }
        h.controller.start()
        h.controller.toggle()
        #expect(seen == [.hidden(count: 1), .shown])
    }

    // Review Focus 1: a second click while macOS is still answering the first means "show".
    @Test func doubleToggleWhileActivatingEndsShownWithNoAssertion() {
        let h = Harness(); defer { h.tearDown() }
        h.restriction.holdCompletions = true
        h.controller.toggle()
        h.controller.toggle()
        h.restriction.releasePending()
        #expect(h.controller.state == .shown)
        #expect(h.restriction.liveTokens.isEmpty)
    }

    // Review Focus 3: quitting mid-activation must not leave a late assertion alive.
    @Test func quitWhileActivatingLeavesNoAssertion() {
        let h = Harness(); defer { h.tearDown() }
        h.restriction.holdCompletions = true
        h.controller.start()
        h.controller.prepareForQuit()
        h.restriction.releasePending()
        #expect(h.restriction.liveTokens.isEmpty)
    }
}
