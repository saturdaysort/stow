import Foundation

/// Why Stow can't hide right now. Stow behaves as Shown meanwhile (spec 4.1, 4.6).
public enum UnavailableReason: Equatable, Sendable {
    case notInApplications
    case frameworkMissing
    case activationFailed(String)
}

public enum HideState: Equatable, Sendable {
    case shown
    case hidden(count: Int)
    case unavailable(UnavailableReason)
}

/// The Hidden / Shown / Unavailable state machine (spec 4).
///
/// Callback-driven on purpose. Every request bumps `generation`, and a completion
/// from an older generation is invalidated on arrival. That makes double clicks and
/// quitting mid-activation safe: a late assertion can never stick.
@MainActor
public final class HideController {
    public private(set) var state: HideState = .shown {
        didSet { if state != oldValue { onStateChange?(state) } }
    }

    /// Called on every state change. The menu bar icon listens to this.
    public var onStateChange: ((HideState) -> Void)?

    private let restriction: any MenuBarRestriction
    private let preferences: Preferences
    private let scheduler: any Scheduling
    private let runningBundleIDs: @MainActor () -> [String]
    private let isInstalledCorrectly: @MainActor () -> Bool
    private let isBusy: @MainActor () -> Bool
    private let ownBundleID: String

    private var token: (any RestrictionToken)?
    private var wantsHidden = false
    private var generation = 0
    private var activeAllowList: [String] = []
    private var launchTask: (any ScheduledTask)?
    private var rehideTask: (any ScheduledTask)?

    public init(restriction: any MenuBarRestriction,
                preferences: Preferences,
                scheduler: any Scheduling,
                runningBundleIDs: @escaping @MainActor () -> [String],
                isInstalledCorrectly: @escaping @MainActor () -> Bool,
                isBusy: @escaping @MainActor () -> Bool,
                ownBundleID: String) {
        self.restriction = restriction
        self.preferences = preferences
        self.scheduler = scheduler
        self.runningBundleIDs = runningBundleIDs
        self.isInstalledCorrectly = isInstalledCorrectly
        self.isBusy = isBusy
        self.ownBundleID = ownBundleID
    }

    /// Launch, including at login: hide right away if there's anything to hide.
    public func start() {
        if preferences.hiddenBundleIDs.isEmpty {
            state = .shown
        } else {
            hide()
        }
    }

    /// Click, shortcut or menu item. Goes by the intended state, so a second click
    /// while a hide is still being applied means "show", not "hide again".
    public func toggle() {
        if wantsHidden {
            show(userInitiated: true)
        } else {
            hide()
        }
    }

    public func hide() {
        cancelRehide()
        wantsHidden = true
        activate()
    }

    public func show(userInitiated: Bool = true) {
        cancelRehide()
        wantsHidden = false
        generation += 1   // anything still in flight is now stale
        token?.invalidate()
        token = nil
        state = .shown
        if userInitiated { scheduleRehide() }
    }

    /// Quit (menu, Command-Q, logout, SIGTERM): release everything before the process exits.
    public func prepareForQuit() {
        cancelRehide()
        launchTask?.cancel()
        launchTask = nil
        wantsHidden = false
        generation += 1
        token?.invalidate()
        token = nil
    }

    /// The user changed which apps to hide (spec 4.1).
    public func hideListChanged() {
        guard wantsHidden else { return }
        if preferences.hiddenBundleIDs.isEmpty {
            show(userInitiated: false)
        } else {
            activate()
        }
    }

    /// An app launched. Refresh the allow-list so it stays visible. Debounced 0.5s so a
    /// burst of launches (login) causes one refresh (spec 4.4).
    public func appLaunched() {
        launchTask?.cancel()
        launchTask = scheduler.schedule(after: 0.5) { [weak self] in
            guard let self, self.wantsHidden, self.token != nil else { return }
            self.activate()
        }
    }

    // MARK: - Activation

    private func activate() {
        let hidden = preferences.hiddenBundleIDs
        guard !hidden.isEmpty else {
            // Never pay exam mode's side effects for nothing, and release anything still held
            // (the list may have been emptied outside Stow while Hidden).
            show(userInitiated: false)
            return
        }
        guard isInstalledCorrectly() else { return fail(.notInApplications) }
        guard restriction.isAvailable else { return fail(.frameworkMissing) }

        let allowed = AllowList.compute(running: runningBundleIDs(), hidden: hidden, own: ownBundleID)
        if token != nil, allowed == activeAllowList {
            // Already restricted to exactly this list: just update the count (no swap, no flicker).
            state = .hidden(count: hidden.count)
            return
        }

        generation += 1
        let request = generation
        restriction.activate(allowing: allowed, systemItems: AllowList.systemItems) { [weak self] result in
            guard let self, request == self.generation, self.wantsHidden else {
                // Superseded by a later click, swap or quit: never let a late assertion stick.
                if case .success(let stale) = result { stale.invalidate() }
                return
            }
            switch result {
            case .success(let newToken):
                let previous = self.token
                self.token = newToken
                self.activeAllowList = allowed
                previous?.invalidate()   // the new list is live before the old one goes (spec 4.4)
                self.state = .hidden(count: hidden.count)
            case .failure(let error):
                // Already hiding with an older list: keep it rather than flash everything back (spec 4.4).
                if self.token != nil { return }
                self.fail(.activationFailed(error.localizedDescription))
            }
        }
    }

    private func fail(_ reason: UnavailableReason) {
        wantsHidden = false
        token?.invalidate()
        token = nil
        state = .unavailable(reason)
    }

    // MARK: - Auto re-hide (spec 4.5)

    private func scheduleRehide() {
        guard let seconds = preferences.rehideDelay.seconds, !preferences.hiddenBundleIDs.isEmpty else { return }
        rehideTask = scheduler.schedule(after: seconds) { [weak self] in self?.rehideDue() }
    }

    /// Waits while the pointer is in the menu bar or a menu is open, re-checking every second.
    private func rehideDue() {
        guard !wantsHidden else { return }
        if isBusy() {
            rehideTask = scheduler.schedule(after: 1) { [weak self] in self?.rehideDue() }
        } else {
            hide()
        }
    }

    private func cancelRehide() {
        rehideTask?.cancel()
        rehideTask = nil
    }
}
