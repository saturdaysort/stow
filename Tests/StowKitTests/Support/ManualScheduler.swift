import Foundation
@testable import StowKit

/// A scheduler whose clock only moves when a test calls `advance(by:)`.
@MainActor final class ManualScheduler: Scheduling {
    @MainActor final class Entry: ScheduledTask {
        let fireAt: TimeInterval
        let action: @MainActor () -> Void
        var isCancelled = false

        init(fireAt: TimeInterval, action: @escaping @MainActor () -> Void) {
            self.fireAt = fireAt
            self.action = action
        }

        func cancel() { isCancelled = true }
    }

    private(set) var now: TimeInterval = 0
    private var entries: [Entry] = []

    var pendingCount: Int { entries.filter { !$0.isCancelled }.count }

    func schedule(after seconds: TimeInterval, _ action: @escaping @MainActor () -> Void) -> any ScheduledTask {
        let entry = Entry(fireAt: now + seconds, action: action)
        entries.append(entry)
        return entry
    }

    /// Moves the clock forward, firing due work in time order. Work may schedule more work.
    func advance(by seconds: TimeInterval) {
        let target = now + seconds
        while let next = entries.filter({ !$0.isCancelled && $0.fireAt <= target + 1e-9 })
            .min(by: { $0.fireAt < $1.fireAt }) {
            now = next.fireAt
            next.isCancelled = true
            next.action()
        }
        now = target
    }
}
