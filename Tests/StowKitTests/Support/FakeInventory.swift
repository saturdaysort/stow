@testable import StowKit

@MainActor final class FakeInventory: InventoryScanning {
    var isTrusted = true
    var found: [MenuBarApp] = []
    var names: [String: String] = [:]
    private(set) var trustRequests = 0
    private(set) var scans = 0

    func requestTrust() { trustRequests += 1 }
    func scan() async -> [MenuBarApp] {
        scans += 1
        return isTrusted ? found : []
    }
    func displayName(for bundleID: String) -> String? { names[bundleID] }
}
