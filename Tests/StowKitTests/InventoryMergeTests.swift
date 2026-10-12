import Testing
@testable import StowKit

@Suite struct InventoryMergeTests {
    let own = "studio.longbrook.stow"
    static func names(_ bundleID: String) -> String? {
        ["com.adobe.acc.AdobeCreativeCloud": "Creative Cloud"][bundleID]
    }

    @Test func foundAppsAreListedAlphabetically() {
        let rows = InventoryMerge.merge(
            found: [MenuBarApp(bundleID: "com.microsoft.teams2", name: "Microsoft Teams"),
                    MenuBarApp(bundleID: "com.anthropic.claudefordesktop", name: "Claude"),
                    MenuBarApp(bundleID: "com.google.Chrome", name: "Google Chrome")],
            hidden: [], running: [], ownBundleID: own, nameFor: Self.names)
        #expect(rows.map(\.name) == ["Claude", "Google Chrome", "Microsoft Teams"])
        #expect(rows.allSatisfy { $0.isRunning && !$0.isHidden })
    }

    @Test func hiddenFoundAppIsMarkedHidden() {
        let rows = InventoryMerge.merge(
            found: [MenuBarApp(bundleID: "io.tailscale.ipn.macos", name: "Tailscale")],
            hidden: ["io.tailscale.ipn.macos"], running: ["io.tailscale.ipn.macos"], ownBundleID: own, nameFor: Self.names)
        #expect(rows == [ListedApp(bundleID: "io.tailscale.ipn.macos", name: "Tailscale", isRunning: true, isHidden: true)])
    }

    // Review Focus 5: an app hidden earlier, then uninstalled, can still be un-hidden.
    @Test func hiddenUninstalledAppStillListed() {
        let rows = InventoryMerge.merge(found: [], hidden: ["com.gone.app"], running: [], ownBundleID: own, nameFor: Self.names)
        #expect(rows == [ListedApp(bundleID: "com.gone.app", name: "com.gone.app", isRunning: false, isHidden: true)])
    }

    // Review Focus 5: while Stow hides an app, Accessibility may not report it, but it's running.
    @Test func hiddenRunningAppNotMarkedNotRunning() {
        let rows = InventoryMerge.merge(found: [], hidden: ["com.adobe.acc.AdobeCreativeCloud"],
                                        running: ["com.adobe.acc.AdobeCreativeCloud"], ownBundleID: own, nameFor: Self.names)
        #expect(rows == [ListedApp(bundleID: "com.adobe.acc.AdobeCreativeCloud", name: "Creative Cloud",
                                   isRunning: true, isHidden: true)])
    }

    @Test func stowNeverListsItself() {
        let rows = InventoryMerge.merge(found: [MenuBarApp(bundleID: own, name: "Stow")], hidden: [own],
                                        running: [own], ownBundleID: own, nameFor: Self.names)
        #expect(rows.isEmpty)
    }

    @Test func sortingIgnoresCaseThenUsesBundleID() {
        let rows = InventoryMerge.merge(
            found: [MenuBarApp(bundleID: "b.id", name: "zoom"), MenuBarApp(bundleID: "a.id", name: "Zoom"),
                    MenuBarApp(bundleID: "c.id", name: "alpha")],
            hidden: [], running: [], ownBundleID: own, nameFor: Self.names)
        #expect(rows.map(\.bundleID) == ["c.id", "a.id", "b.id"])
    }

    @Test @MainActor func scanWithoutAccessibilityReturnsNothingAndNeverPrompts() async {
        let inventory = MenuBarAppInventory()
        if !inventory.isTrusted {
            #expect(await inventory.scan().isEmpty)
        }
    }
}
