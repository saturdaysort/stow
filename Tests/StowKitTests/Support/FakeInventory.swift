@testable import StowKit

@MainActor final class FakeInventory: InventoryScanning {
    var isTrusted = true
    var found: [MenuBarApp] = []
    var names: [String: String] = [:]
    private(set) var trustRequests = 0

    func requestTrust() { trustRequests += 1 }
    func scan() async -> [MenuBarApp] { isTrusted ? found : [] }
    func displayName(for bundleID: String) -> String? { names[bundleID] }
}
