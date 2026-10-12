import AppKit
import Observation

/// Settings copy whose wording depends on what on-device testing finds (spec 5.3, check 4).
public enum SettingsCopy {
    public static let aboutHiding = "Stow hides apps using macOS's exam mode. While icons are hidden, clicking the clock won't open Notification Center, and Focus, Now Playing and the microphone and camera indicators may be hidden too."
}

/// Everything the Settings window shows and does (spec 5.3 to 5.5).
@MainActor @Observable
public final class SettingsModel {
    public private(set) var apps: [ListedApp] = []
    public private(set) var isTrusted = false
    public private(set) var isInstalledCorrectly = true
    public private(set) var loginStatus: LoginItemStatus = .disabled
    public private(set) var rehideDelay: RehideDelay
    public private(set) var shortcut: Shortcut?
    public private(set) var shortcutError: String?

    /// Called after anything that changes what the menu bar item should show.
    @ObservationIgnored public var onChange: (@MainActor () -> Void)?

    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private let hideController: HideController
    @ObservationIgnored private let inventory: any InventoryScanning
    @ObservationIgnored private let loginItem: any LoginItemControlling
    @ObservationIgnored private let shortcuts: ShortcutController
    @ObservationIgnored private let ownBundleID: String
    @ObservationIgnored private let runningBundleIDs: @MainActor () -> [String]
    @ObservationIgnored private let isInstalled: @MainActor () -> Bool
    @ObservationIgnored private let openURL: @MainActor (URL) -> Void

    /// System Settings › Menu Bar: the Control Center settings extension on macOS 26 and later.
    public static let menuBarSettingsURL = URL(string: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension")!

    public init(preferences: Preferences,
                hideController: HideController,
                inventory: any InventoryScanning,
                loginItem: any LoginItemControlling,
                shortcuts: ShortcutController,
                ownBundleID: String,
                runningBundleIDs: @escaping @MainActor () -> [String],
                isInstalled: @escaping @MainActor () -> Bool,
                openURL: @escaping @MainActor (URL) -> Void) {
        self.preferences = preferences
        self.hideController = hideController
        self.inventory = inventory
        self.loginItem = loginItem
        self.shortcuts = shortcuts
        self.ownBundleID = ownBundleID
        self.runningBundleIDs = runningBundleIDs
        self.isInstalled = isInstalled
        self.openURL = openURL
        rehideDelay = preferences.rehideDelay
        shortcut = preferences.shortcut
    }

    /// Re-reads everything, including a fresh Accessibility scan.
    public func refresh() async {
        isTrusted = inventory.isTrusted
        isInstalledCorrectly = isInstalled()
        loginStatus = loginItem.status
        rehideDelay = preferences.rehideDelay
        shortcut = preferences.shortcut
        shortcutError = shortcuts.lastError
        let found = await inventory.scan()
        let hidden = preferences.hiddenBundleIDs
        let names = Dictionary(uniqueKeysWithValues: hidden.compactMap { id in
            inventory.displayName(for: id).map { (id, $0) }
        })
        apps = InventoryMerge.merge(found: found, hidden: hidden, running: Set(runningBundleIDs()),
                                    ownBundleID: ownBundleID, nameFor: { names[$0] })
    }

    public func setHidden(_ app: ListedApp, _ hidden: Bool) {
        preferences.setHidden(app.bundleID, hidden)
        apps = apps.map { row in
            var row = row
            if row.bundleID == app.bundleID { row.isHidden = hidden }
            return row
        }
        hideController.hideListChanged()
        onChange?()
    }

    public func setRehideDelay(_ delay: RehideDelay) {
        preferences.rehideDelay = delay
        rehideDelay = delay
    }

    public func setShortcut(_ new: Shortcut?) {
        shortcuts.apply(new)
        shortcut = preferences.shortcut
        shortcutError = shortcuts.lastError
        onChange?()
    }

    /// The switch always shows the real state, so a failed change snaps back.
    public func setLoginEnabled(_ enabled: Bool) {
        try? loginItem.setEnabled(enabled)
        loginStatus = loginItem.status
    }

    public func requestAccessibility() { inventory.requestTrust() }
    public func openLoginItemsSettings() { loginItem.openSystemSettings() }
    public func openMenuBarSettings() { openURL(Self.menuBarSettingsURL) }

    /// Called every second while the Accessibility banner shows. True once access is granted.
    public func pollTrust() async -> Bool {
        guard !isTrusted else { return true }
        guard inventory.isTrusted else { return false }
        await refresh()
        return true
    }
}
