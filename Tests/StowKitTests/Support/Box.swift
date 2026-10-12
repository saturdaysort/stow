/// A mutable reference for values captured by @MainActor closures in tests.
/// Those closures are Sendable, so they can't capture a local `var`.
@MainActor final class Box<Value> {
    var value: Value
    init(_ value: Value) { self.value = value }
}
