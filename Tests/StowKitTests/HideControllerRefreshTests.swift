import Testing
@testable import StowKit

@Suite @MainActor struct HideControllerRefreshTests {
    @Test func launchedAppStaysVisibleNewListGoesUpFirst() {
        let h = Harness(); defer { h.tearDown() }
        h.controller.start()                       // token 1
        h.running.append("com.example.new")
        h.controller.appLaunched()
        h.scheduler.advance(by: 0.5)
        #expect(h.restriction.events == [
            .activate(["com.apple.finder", "com.example.chat", "studio.longbrook.stow"]),
            .activate(["com.apple.finder", "com.example.chat", "com.example.new", "studio.longbrook.stow"]),
            .invalidate(1),
        ])
        #expect(h.restriction.liveTokens.map(\.id) == [2])
        #expect(h.controller.state == .hidden(count: 1))
    }

    // Review Focus 2: about ten launches at login cause one refresh.
    @Test func launchBurstRefreshesOnce() {
        let h = Harness(); defer { h.tearDown() }
        h.controller.start()
        for index in 0..<10 {
            h.running.append("com.example.app\(index)")
            h.controller.appLaunched()
            h.scheduler.advance(by: 0.04)
        }
        h.scheduler.advance(by: 0.5)
        #expect(h.restriction.activations.count == 2)
        #expect(h.restriction.liveTokens.count == 1)
    }

    @Test func failedRefreshKeepsHidingWithTheOldList() {
        let h = Harness(); defer { h.tearDown() }
        h.controller.start()
        h.restriction.refuse = true
        h.controller.appLaunched()
        h.scheduler.advance(by: 0.5)
        #expect(h.restriction.liveTokens.map(\.id) == [1])
        #expect(h.controller.state == .hidden(count: 1))
    }

    @Test func launchesWhileShownChangeNothing() {
        let h = Harness(); defer { h.tearDown() }
        h.controller.start()
        h.controller.toggle()
        h.controller.appLaunched()
        h.scheduler.advance(by: 0.5)
        #expect(h.restriction.activations.count == 1)
    }

    @Test func changingTheListWhileHiddenSwapsLists() {
        let h = Harness(); defer { h.tearDown() }
        h.controller.start()
        h.preferences.setHidden("com.example.chat", true)
        h.controller.hideListChanged()
        #expect(Array(h.restriction.events.suffix(2)) == [
            .activate(["com.apple.finder", "studio.longbrook.stow"]),
            .invalidate(1),
        ])
        #expect(h.controller.state == .hidden(count: 2))
    }

    @Test func emptyingTheListWhileHiddenShowsEverything() {
        let h = Harness(); defer { h.tearDown() }
        h.controller.start()
        h.preferences.hiddenBundleIDs = []
        h.controller.hideListChanged()
        #expect(h.controller.state == .shown)
        #expect(h.restriction.liveTokens.isEmpty)
    }

    @Test func changingTheListWhileShownDoesNotHide() {
        let h = Harness(); defer { h.tearDown() }
        h.controller.start()
        h.controller.toggle()
        h.preferences.setHidden("com.example.chat", true)
        h.controller.hideListChanged()
        #expect(h.controller.state == .shown)
        #expect(h.restriction.activations.count == 1)
    }

    @Test func quitCancelsAPendingRefresh() {
        let h = Harness(); defer { h.tearDown() }
        h.controller.start()
        h.controller.appLaunched()
        h.controller.prepareForQuit()
        h.scheduler.advance(by: 0.5)
        #expect(h.restriction.activations.count == 1)
        #expect(h.restriction.liveTokens.isEmpty)
    }
}
