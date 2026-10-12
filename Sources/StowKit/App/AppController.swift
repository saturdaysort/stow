import AppKit

/// First launch: register the login item, open Settings (spec 5.5).
public enum FirstRun {
    @MainActor
    public static func isNeeded(_ preferences: Preferences) -> Bool {
        !preferences.hasCompletedFirstRun
    }
}

/// Builds and connects every part of Stow. The app delegate owns it for the app's lifetime.
@MainActor
public final class AppController {
    private let preferences: Preferences
    private let ownBundleID: String
    private let hideController: HideController
    private let shortcutController: ShortcutController
    private let loginItem = LoginItem()
    private let inventory = MenuBarAppInventory()
    private var statusItem: StatusItemController?
    private var settingsWindow: SettingsWindowController?
    private var launchObserver: (any NSObjectProtocol)?
    private var terminationSignal: (any DispatchSourceSignal)?

    public init() {
        let preferences = Preferences()
        let ownBundleID = Bundle.main.bundleIdentifier ?? StowKit.bundleIdentifier
        let hideController = HideController(
            restriction: ExamModeRestriction(),
            preferences: preferences,
            scheduler: TaskScheduler(),
            runningBundleIDs: { RunningApps.bundleIDs() },
            isInstalledCorrectly: { InstallLocation.isExpected(Bundle.main.bundleURL) },
            isBusy: { MenuBarBusyProbe.isBusy() },
            ownBundleID: ownBundleID)
        self.preferences = preferences
        self.ownBundleID = ownBundleID
        self.hideController = hideController
        self.shortcutController = ShortcutController(registrar: CarbonHotKey(), preferences: preferences,
                                                     onPress: { hideController.toggle() })
    }

    /// Called once, from applicationDidFinishLaunching.
    public func launch() {
        let model = SettingsModel(
            preferences: preferences,
            hideController: hideController,
            inventory: inventory,
            loginItem: loginItem,
            shortcuts: shortcutController,
            ownBundleID: ownBundleID,
            runningBundleIDs: { RunningApps.bundleIDs() },
            isInstalled: { InstallLocation.isExpected(Bundle.main.bundleURL) },
            openURL: { url in
                // Fallback for open question 5: if the pane link fails, open System Settings itself.
                if !NSWorkspace.shared.open(url) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
                }
            })
        let settingsWindow = SettingsWindowController(model: model)
        self.settingsWindow = settingsWindow
        let statusItem = StatusItemController(hideController: hideController, preferences: preferences,
                                              openSettings: { settingsWindow.show() })
        self.statusItem = statusItem
        hideController.onStateChange = { _ in statusItem.refresh() }
        model.onChange = { statusItem.refresh() }

        shortcutController.start()
        observeAppLaunches()
        routeTerminationSignal()

        if FirstRun.isNeeded(preferences) {
            try? loginItem.setEnabled(true)   // Open at login defaults to on (spec 5.5)
            preferences.hasCompletedFirstRun = true
            settingsWindow.show()
        }
        hideController.start()
        statusItem.refresh()
    }

    /// Called from applicationWillTerminate: release the assertion before the process exits.
    public func terminate() {
        hideController.prepareForQuit()
    }

    private func observeAppLaunches() {
        let hideController = hideController
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { hideController.appLaunched() }
        }
    }

    /// `pkill` and scripts/install.sh send SIGTERM, which would otherwise end the process
    /// without applicationWillTerminate. Route it through NSApp.terminate so the assertion is released.
    private func routeTerminationSignal() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated { NSApp.terminate(nil) }
        }
        source.resume()
        terminationSignal = source
    }
}
