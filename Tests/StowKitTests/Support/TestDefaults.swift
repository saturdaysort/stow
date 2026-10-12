import Foundation

/// A throwaway UserDefaults suite per test, removed by `cleanup`.
enum TestDefaults {
    static func make() -> (UserDefaults, cleanup: () -> Void) {
        let name = "stow-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (defaults, { UserDefaults().removePersistentDomain(forName: name) })
    }
}
