import AppKit
import Testing
@testable import StowKit

/// Stands in for NSWorkspace: reports changes to `runningApplications` the way KVO does.
final class FakeWorkspace: NSObject {
    private var storage: [String] = []
    @objc var runningApplications: [String] { storage }

    func launch(_ id: String) {
        report(.insertion, at: storage.count) { storage.append(id) }
    }

    func quit(_ id: String) {
        guard let index = storage.firstIndex(of: id) else { return }
        report(.removal, at: index) { storage.remove(at: index) }
    }

    func replaceAll(_ ids: [String]) {
        willChangeValue(forKey: "runningApplications")
        storage = ids
        didChangeValue(forKey: "runningApplications")
    }

    private func report(_ kind: NSKeyValueChange, at index: Int, _ body: () -> Void) {
        let indexes = IndexSet(integer: index)
        willChange(kind, valuesAt: indexes, forKey: "runningApplications")
        body()
        didChange(kind, valuesAt: indexes, forKey: "runningApplications")
    }
}

// Review finding 1: on macOS 27.2 NSWorkspace.didLaunchApplicationNotification isn't posted
// for agent or accessory apps (most menu bar apps); KVO on runningApplications sees them all.
@Suite @MainActor struct AppLaunchWatcherTests {
    @Test func launchesAndQuitsAreReported() {
        let workspace = FakeWorkspace()
        let changes = Box<[AppLaunchWatcher.Change]>([])
        let watcher = AppLaunchWatcher(source: workspace) { changes.value.append($0) }
        watcher.start()
        workspace.launch("io.tailscale.ipn.macos")
        workspace.quit("io.tailscale.ipn.macos")
        #expect(changes.value == [.launched, .quit])
        watcher.stop()
    }

    @Test func wholesaleReplacementCountsAsALaunch() {
        let workspace = FakeWorkspace()
        let changes = Box<[AppLaunchWatcher.Change]>([])
        let watcher = AppLaunchWatcher(source: workspace) { changes.value.append($0) }
        watcher.start()
        workspace.replaceAll(["a", "b"])
        #expect(changes.value == [.launched])
        watcher.stop()
    }

    @Test func nothingIsReportedAfterStop() {
        let workspace = FakeWorkspace()
        let changes = Box<[AppLaunchWatcher.Change]>([])
        let watcher = AppLaunchWatcher(source: workspace) { changes.value.append($0) }
        watcher.start()
        watcher.stop()
        workspace.launch("com.example.app")
        #expect(changes.value.isEmpty)
    }
}
