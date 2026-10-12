import Foundation

/// How long icons stay visible after you reveal them.
public enum RehideDelay: Int, CaseIterable, Sendable, Identifiable {
    case never = 0
    case fiveSeconds = 5
    case tenSeconds = 10
    case thirtySeconds = 30
    case oneMinute = 60

    public var id: Int { rawValue }

    /// nil means never re-hide.
    public var seconds: TimeInterval? { self == .never ? nil : TimeInterval(rawValue) }

    public var title: String {
        switch self {
        case .never: "Never"
        case .fiveSeconds: "5 seconds"
        case .tenSeconds: "10 seconds"
        case .thirtySeconds: "30 seconds"
        case .oneMinute: "1 minute"
        }
    }

    /// The allowed value closest to `seconds`. Zero or less means Never; ties go to the shorter delay.
    public static func nearest(to seconds: Int) -> RehideDelay {
        guard seconds > 0 else { return .never }
        let timed = allCases.filter { $0 != .never }
        return timed.min { a, b in
            let da = abs(a.rawValue - seconds), db = abs(b.rawValue - seconds)
            return da != db ? da < db : a.rawValue < b.rawValue
        }!
    }
}

/// Stow's saved settings. The login-item state is deliberately not stored here:
/// it's read live from SMAppService so there's one source of truth (spec 6.3).
@MainActor
public final class Preferences {
    enum Key {
        static let hiddenBundleIDs = "hiddenBundleIDs"
        static let rehideDelaySeconds = "rehideDelaySeconds"
        static let shortcutKeyCode = "shortcutKeyCode"
        static let shortcutModifiers = "shortcutModifiers"
        static let hasCompletedFirstRun = "hasCompletedFirstRun"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Apps to hide, by bundle ID. Always sorted, unique, without empty strings.
    public var hiddenBundleIDs: [String] {
        get {
            let raw = defaults.array(forKey: Key.hiddenBundleIDs) ?? []
            return Self.normalized(raw.compactMap { $0 as? String })
        }
        set { defaults.set(Self.normalized(newValue), forKey: Key.hiddenBundleIDs) }
    }

    public func isHidden(_ bundleID: String) -> Bool {
        hiddenBundleIDs.contains(bundleID)
    }

    public func setHidden(_ bundleID: String, _ hidden: Bool) {
        var ids = Set(hiddenBundleIDs)
        if hidden { ids.insert(bundleID) } else { ids.remove(bundleID) }
        hiddenBundleIDs = Array(ids)
    }

    public var rehideDelay: RehideDelay {
        get {
            guard let value = defaults.object(forKey: Key.rehideDelaySeconds) as? Int else { return .tenSeconds }
            return RehideDelay(rawValue: value) ?? .nearest(to: value)
        }
        set { defaults.set(newValue.rawValue, forKey: Key.rehideDelaySeconds) }
    }

    /// nil means the user cleared the shortcut. Missing or unusable stored values give ⌃⌥H.
    public var shortcut: Shortcut? {
        get {
            guard let code = defaults.object(forKey: Key.shortcutKeyCode) as? Int else { return .defaultShortcut }
            if code == -1 { return nil }
            guard (0...0xFFFF).contains(code),
                  let modifiers = defaults.object(forKey: Key.shortcutModifiers) as? Int, modifiers >= 0
            else { return .defaultShortcut }
            let shortcut = Shortcut(keyCode: UInt32(code), modifiers: UInt32(modifiers))
            return shortcut.isValid ? shortcut : .defaultShortcut
        }
        set {
            if let shortcut = newValue {
                defaults.set(Int(shortcut.keyCode), forKey: Key.shortcutKeyCode)
                defaults.set(Int(shortcut.modifiers), forKey: Key.shortcutModifiers)
            } else {
                defaults.set(-1, forKey: Key.shortcutKeyCode)
                defaults.removeObject(forKey: Key.shortcutModifiers)
            }
        }
    }

    public var hasCompletedFirstRun: Bool {
        get { defaults.bool(forKey: Key.hasCompletedFirstRun) }
        set { defaults.set(newValue, forKey: Key.hasCompletedFirstRun) }
    }

    private static func normalized(_ ids: [String]) -> [String] {
        Array(Set(ids.filter { !$0.isEmpty })).sorted()
    }
}
