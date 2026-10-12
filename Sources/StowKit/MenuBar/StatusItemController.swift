import AppKit

/// The drawer in the menu bar. Left-click toggles; right-click or Control-click opens the
/// menu (spec 5.1, 5.2).
@MainActor
public final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let hideController: HideController
    private let preferences: Preferences
    private let openSettings: @MainActor () -> Void
    private var appearanceObservation: NSKeyValueObservation?

    public init(hideController: HideController, preferences: Preferences,
                openSettings: @escaping @MainActor () -> Void) {
        self.hideController = hideController
        self.preferences = preferences
        self.openSettings = openSettings
        super.init()
        statusItem.autosaveName = "stow_drawer"
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(buttonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            // Repaint the amber when the menu bar flips between light and dark.
            appearanceObservation = button.observe(\.effectiveAppearance) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
        refresh()
    }

    /// Redraws the icon, tooltip and accessibility label from the current state.
    public func refresh() {
        guard let button = statusItem.button else { return }
        let model = MenuModel.make(state: hideController.state, hiddenCount: preferences.hiddenBundleIDs.count)
        button.image = DrawerGlyph.image(Self.variant(for: hideController.state, appearance: button.effectiveAppearance))
        button.toolTip = model.statusLine
        button.setAccessibilityLabel(model.accessibilityLabel)
    }

    static func variant(for state: HideState, appearance: NSAppearance) -> DrawerGlyph.Variant {
        switch state {
        case .hidden: .closed
        case .shown: .open(darkMenuBar: appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
        case .unavailable: .unavailable
        }
    }

    @objc private func buttonClicked(_ sender: NSStatusBarButton) {
        // On macOS 27, NSApp.currentEvent's modifier flags can be empty here (findings,
        // "Other traps"): decide by event type, and read Control from NSEvent.modifierFlags.
        let wantsMenu = NSApp.currentEvent?.type == .rightMouseUp || NSEvent.modifierFlags.contains(.control)
        if wantsMenu {
            showMenu()
        } else {
            hideController.toggle()
        }
    }

    private func showMenu() {
        let model = MenuModel.make(state: hideController.state, hiddenCount: preferences.hiddenBundleIDs.count)
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        let toggle = NSMenuItem(title: model.toggleTitle, action: #selector(toggleFromMenu), keyEquivalent: "")
        toggle.target = self
        toggle.isEnabled = model.toggleEnabled
        if let hint = MenuModel.keyEquivalent(for: preferences.shortcut) {
            toggle.keyEquivalent = hint.key
            toggle.keyEquivalentModifierMask = hint.modifiers
        }
        menu.addItem(toggle)

        let status = NSMenuItem(title: model.statusLine, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(settingsFromMenu), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let quit = NSMenuItem(title: "Quit Stow", action: #selector(quitFromMenu), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)   // opens the menu under the drawer
    }

    public func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil   // so the next left-click toggles again
    }

    @objc private func toggleFromMenu() { hideController.toggle() }
    @objc private func settingsFromMenu() { openSettings() }
    @objc private func quitFromMenu() { NSApp.terminate(nil) }
}
