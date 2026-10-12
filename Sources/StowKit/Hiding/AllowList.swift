import AppKit

/// Exam mode is an allow-list: anything not listed disappears from the menu bar,
/// including Stow's own icon, so Stow always lists itself (spec 4.2).
public enum AllowList {
    /// macOS's own menu bar items to keep: clock, Wi-Fi, Control Center and so on.
    /// Same range upstream Hidden Bar uses.
    public static let systemItems: [Int] = Array(0..<64)

    public static func compute(running: [String], hidden: [String], own: String) -> [String] {
        let hiddenSet = Set(hidden).subtracting([own])
        var allowed = Set(running.filter { !$0.isEmpty })
        allowed.insert(own)
        return allowed.subtracting(hiddenSet).sorted()
    }
}

public enum RunningApps {
    /// Bundle IDs of running apps that can own menu bar icons (regular and accessory apps).
    @MainActor
    public static func bundleIDs(in workspace: NSWorkspace = .shared) -> [String] {
        workspace.runningApplications
            .filter { $0.activationPolicy == .regular || $0.activationPolicy == .accessory }
            .compactMap(\.bundleIdentifier)
    }
}

/// Exam mode only recognizes the copy LaunchServices knows as Stow. Any other copy
/// would hide its own icon, so Stow refuses to hide from anywhere else (spec 4.6).
public enum InstallLocation {
    public static let expectedPath = "/Applications/Stow.app"

    public static func isExpected(_ bundleURL: URL) -> Bool {
        bundleURL.standardizedFileURL.resolvingSymlinksInPath().path == expectedPath
    }
}
