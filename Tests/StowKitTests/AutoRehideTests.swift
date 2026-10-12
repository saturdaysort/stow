import Testing
@testable import StowKit

@Suite @MainActor struct AutoRehideTests {
    @Test func rehidesAfterTheDelay() {
        let h = Harness(); defer { h.tearDown() }
        h.controller.start()
        h.controller.toggle()                    // reveal
        h.scheduler.advance(by: 9.9)
        #expect(h.controller.state == .shown)
        h.scheduler.advance(by: 0.1)
        #expect(h.controller.state == .hidden(count: 1))
    }

    @Test func neverMeansNever() {
        let h = Harness(); defer { h.tearDown() }
        h.preferences.rehideDelay = .never
        h.controller.start()
        h.controller.toggle()
        h.scheduler.advance(by: 600)
        #expect(h.controller.state == .shown)
    }

    @Test func waitsWhileThePointerIsInTheMenuBarOrAMenuIsOpen() {
        let h = Harness(); defer { h.tearDown() }
        h.controller.start()
        h.controller.toggle()
        h.busy = true
        h.scheduler.advance(by: 10)
        #expect(h.controller.state == .shown)
        h.scheduler.advance(by: 3)
        #expect(h.controller.state == .shown)
        h.busy = false
        h.scheduler.advance(by: 1)
        #expect(h.controller.state == .hidden(count: 1))
    }

    @Test func manualHideCancelsTheTimer() {
        let h = Harness(); defer { h.tearDown() }
        h.controller.start()
        h.controller.toggle()                    // reveal at t=0, timer due at 10
        h.scheduler.advance(by: 5)
        h.controller.toggle()                    // hide by hand at t=5
        h.scheduler.advance(by: 1)
        h.controller.toggle()                    // reveal again at t=6, new timer due at 16
        h.scheduler.advance(by: 4.5)             // t=10.5: the first timer must not fire
        #expect(h.controller.state == .shown)
        h.scheduler.advance(by: 5.5)             // t=16
        #expect(h.controller.state == .hidden(count: 1))
    }

    @Test func automaticShowsDoNotStartTheTimer() {
        let h = Harness(); defer { h.tearDown() }
        h.controller.start()
        h.preferences.hiddenBundleIDs = []
        h.controller.hideListChanged()           // list emptied: shown, not by the user
        #expect(h.scheduler.pendingCount == 0)
    }
}
