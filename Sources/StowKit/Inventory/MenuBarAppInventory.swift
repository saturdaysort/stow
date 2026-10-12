import AppKit
import ApplicationServices

/// An app that currently shows at least one menu bar icon.
public struct MenuBarApp: Equatable, Sendable {
    public var bundleID: String
    public var name: String

    public init(bundleID: String, name: String) {
        self.bundleID = bundleID
        self.name = name
    }
}

/// One row of the Settings list (spec 5.3).
public struct ListedApp: Equatable, Identifiable, Sendable {
    public var id: String { bundleID }
    public var bundleID: String
    public var name: String
    public var isRunning: Bool
    public var isHidden: Bool

    public init(bundleID: String, name: String, isRunning: Bool, isHidden: Bool) {
        self.bundleID = bundleID
        self.name = name
        self.isRunning = isRunning
        self.isHidden = isHidden
    }
}

public enum InventoryMerge {
    /// Apps with menu bar icons, plus every hidden app (so it can be un-hidden), minus Stow.
    /// `running` decides "Not running", because apps Stow is hiding may be missing from `found`.
    public static func merge(found: [MenuBarApp], hidden: [String], running: Set<String>,
                             ownBundleID: String, nameFor: (String) -> String?) -> [ListedApp] {
        let hiddenSet = Set(hidden)
        var rows: [String: ListedApp] = [:]
        for app in found where app.bundleID != ownBundleID {
            rows[app.bundleID] = ListedApp(bundleID: app.bundleID, name: app.name, isRunning: true,
                                           isHidden: hiddenSet.contains(app.bundleID))
        }
        for id in hiddenSet where id != ownBundleID && rows[id] == nil {
            rows[id] = ListedApp(bundleID: id, name: nameFor(id) ?? id, isRunning: running.contains(id), isHidden: true)
        }
        return rows.values.sorted { a, b in
            let order = a.name.localizedCaseInsensitiveCompare(b.name)
            return order == .orderedSame ? a.bundleID < b.bundleID : order == .orderedAscending
        }
    }
}

/// What Settings needs from the Accessibility scan. Injected so tests don't need permissions.
@MainActor public protocol InventoryScanning: AnyObject {
    var isTrusted: Bool { get }
    func requestTrust()
    func scan() async -> [MenuBarApp]
    func displayName(for bundleID: String) -> String?
}

/// Finds which running apps have menu bar icons, through Accessibility (spec 6.5).
/// Accessibility is the only permission Stow ever asks for.
@MainActor public final class MenuBarAppInventory: InventoryScanning {
    public init() {}

    public var isTrusted: Bool {
        // The kAXTrustedCheckOptionPrompt global isn't concurrency-safe in Swift 6; use its value.
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": false] as CFDictionary)
    }

    /// Adds Stow to the Accessibility list and opens that privacy pane.
    public func requestTrust() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public func scan() async -> [MenuBarApp] {
        guard isTrusted else { return [] }
        let candidates = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular || $0.activationPolicy == .accessory }
            .compactMap { app -> Candidate? in
                guard let id = app.bundleIdentifier else { return nil }
                return Candidate(pid: app.processIdentifier, bundleID: id, name: app.localizedName ?? id)
            }
        // Off the main thread: an unresponsive app can make each Accessibility call wait 0.25s.
        return await Task.detached(priority: .userInitiated) {
            MenuBarAppInventory.appsWithMenuBarItems(candidates)
        }.value
    }

    public func displayName(for bundleID: String) -> String? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?
            .deletingPathExtension().lastPathComponent
    }

    struct Candidate: Sendable {
        let pid: pid_t
        let bundleID: String
        let name: String
    }

    nonisolated static func appsWithMenuBarItems(_ candidates: [Candidate]) -> [MenuBarApp] {
        candidates.compactMap { candidate in
            let element = AXUIElementCreateApplication(candidate.pid)
            AXUIElementSetMessagingTimeout(element, 0.25)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, "AXExtrasMenuBar" as CFString, &value) == .success,
                  let bar = value, CFGetTypeID(bar) == AXUIElementGetTypeID() else { return nil }
            var children: CFTypeRef?
            guard AXUIElementCopyAttributeValue(unsafeDowncast(bar, to: AXUIElement.self),
                                                "AXChildren" as CFString, &children) == .success,
                  let items = children as? [AnyObject], !items.isEmpty else { return nil }
            return MenuBarApp(bundleID: candidate.bundleID, name: candidate.name)
        }
    }
}
