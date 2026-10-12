@testable import StowKit

/// Mirrors Carbon: registering first drops the current hot key, and a taken
/// combination leaves nothing registered.
@MainActor final class FakeRegistrar: HotKeyRegistering {
    var onPress: (@MainActor () -> Void)?
    var taken: [Shortcut] = []
    private(set) var registered: Shortcut?

    func register(_ shortcut: Shortcut) throws {
        registered = nil
        if taken.contains(shortcut) { throw ShortcutError.inUse }
        registered = shortcut
    }

    func unregister() { registered = nil }
}
