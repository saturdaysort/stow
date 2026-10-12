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
        wantsHidden = true
        activate()
    }

    public func show(userInitiated: Bool = true) {
        wantsHidden = false
        generation += 1   // anything still in flight is now stale
        token?.invalidate()
        token = nil
        state = .shown
    }

    /// Quit (menu, Command-Q, logout, SIGTERM): release everything before the process exits.
    public func prepareForQuit() {
        wantsHidden = false
        generation += 1
        token?.invalidate()
        token = nil
    }

    // MARK: - Activation

    private func activate() {
        let hidden = preferences.hiddenBundleIDs
        guard !hidden.isEmpty else {
            // Never pay exam mode's side effects for nothing.
            wantsHidden = false
            state = .shown
            return
        }
        guard isInstalledCorrectly() else { return fail(.notInApplications) }
        guard restriction.isAvailable else { return fail(.frameworkMissing) }

        generation += 1
        let request = generation
        let allowed = AllowList.compute(running: runningBundleIDs(), hidden: hidden, own: ownBundleID)
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
}
