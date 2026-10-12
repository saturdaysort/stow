import Foundation

/// A cancellable piece of scheduled work.
@MainActor public protocol ScheduledTask {
    func cancel()
}

/// Runs work later on the main actor. Injected so tests control time.
@MainActor public protocol Scheduling {
    func schedule(after seconds: TimeInterval, _ action: @escaping @MainActor () -> Void) -> any ScheduledTask
}

/// The real scheduler: a sleeping task on the main actor.
@MainActor public final class TaskScheduler: Scheduling {
    public init() {}

    public func schedule(after seconds: TimeInterval, _ action: @escaping @MainActor () -> Void) -> any ScheduledTask {
        let task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            if !Task.isCancelled { action() }
        }
        return TaskHandle(task: task)
    }
}

@MainActor private struct TaskHandle: ScheduledTask {
    let task: Task<Void, Never>
    func cancel() { task.cancel() }
}
