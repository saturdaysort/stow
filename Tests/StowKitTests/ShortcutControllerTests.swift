import Testing
@testable import StowKit

@Suite @MainActor struct ShortcutControllerTests {
    @Test func startRegistersTheSavedShortcut() {
        let (defaults, cleanup) = TestDefaults.make(); defer { cleanup() }
        let registrar = FakeRegistrar()
        let controller = ShortcutController(registrar: registrar, preferences: Preferences(defaults: defaults), onPress: {})
        controller.start()
        #expect(registrar.registered == .defaultShortcut)
        #expect(controller.lastError == nil)
    }

    @Test func applyingANewShortcutRegistersAndSavesIt() {
        let (defaults, cleanup) = TestDefaults.make(); defer { cleanup() }
        let prefs = Preferences(defaults: defaults)
        let registrar = FakeRegistrar()
        let controller = ShortcutController(registrar: registrar, preferences: prefs, onPress: {})
        controller.start()
        let new = Shortcut(keyCode: 3, modifiers: 256)
        #expect(controller.apply(new))
        #expect(registrar.registered == new)
        #expect(prefs.shortcut == new)
    }

    @Test func conflictKeepsThePreviousShortcut() {
        let (defaults, cleanup) = TestDefaults.make(); defer { cleanup() }
        let prefs = Preferences(defaults: defaults)
        let registrar = FakeRegistrar()
        let controller = ShortcutController(registrar: registrar, preferences: prefs, onPress: {})
        controller.start()
        let taken = Shortcut(keyCode: 3, modifiers: 256)
        registrar.taken = [taken]
        #expect(!controller.apply(taken))
        #expect(controller.lastError == "That shortcut is used by another app")
        #expect(registrar.registered == .defaultShortcut)
        #expect(prefs.shortcut == .defaultShortcut)
    }

    @Test func clearingUnregistersAndSavesNone() {
        let (defaults, cleanup) = TestDefaults.make(); defer { cleanup() }
        let prefs = Preferences(defaults: defaults)
        let registrar = FakeRegistrar()
        let controller = ShortcutController(registrar: registrar, preferences: prefs, onPress: {})
        controller.start()
        #expect(controller.apply(nil))
        #expect(registrar.registered == nil)
        #expect(prefs.shortcut == nil)
    }

    @Test func takenAtLaunchIsReported() {
        let (defaults, cleanup) = TestDefaults.make(); defer { cleanup() }
        let registrar = FakeRegistrar()
        registrar.taken = [.defaultShortcut]
        let controller = ShortcutController(registrar: registrar, preferences: Preferences(defaults: defaults), onPress: {})
        controller.start()
        #expect(controller.lastError == "That shortcut is used by another app")
    }

    @Test func pressingTheShortcutRunsTheAction() {
        let (defaults, cleanup) = TestDefaults.make(); defer { cleanup() }
        let registrar = FakeRegistrar()
        let presses = Box(0)
        let controller = ShortcutController(registrar: registrar, preferences: Preferences(defaults: defaults),
                                            onPress: { presses.value += 1 })
        registrar.onPress?()
        #expect(presses.value == 1)
        _ = controller
    }
}
