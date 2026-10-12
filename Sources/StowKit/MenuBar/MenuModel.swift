import AppKit
import Carbon.HIToolbox

/// What the right-click menu and the icon's accessibility label say, by state (spec 5.1, 5.2).
public struct MenuModel: Equatable, Sendable {
    public var toggleTitle: String
    public var toggleEnabled: Bool
    public var statusLine: String
    public var accessibilityLabel: String

    public static func make(state: HideState, hiddenCount: Int) -> MenuModel {
        switch state {
        case .hidden(let count):
            return MenuModel(toggleTitle: "Show Hidden Icons", toggleEnabled: true,
                             statusLine: "Hiding \(apps(count))",
                             accessibilityLabel: "Stow, \(apps(count)) hidden")
        case .shown:
            return MenuModel(toggleTitle: "Hide Icons", toggleEnabled: hiddenCount > 0,
                             statusLine: hiddenCount > 0 ? "All icons showing" : "Pick apps to hide in Settings",
                             accessibilityLabel: "Stow, icons showing")
        case .unavailable(let reason):
            let line = switch reason {
            case .notInApplications: "Move Stow to Applications to hide icons"
            case .frameworkMissing: "Hiding isn't available on this version of macOS"
            case .activationFailed(let message): "Hiding unavailable: \(message)"
            }
            return MenuModel(toggleTitle: "Show Hidden Icons", toggleEnabled: false,
                             statusLine: line, accessibilityLabel: "Stow, hiding unavailable")
        }
    }

    /// The global shortcut as a menu key equivalent, shown as a hint. Only letter and digit
    /// keys qualify; for other keys the menu shows no hint (the shortcut itself still works).
    @MainActor
    public static func keyEquivalent(for shortcut: Shortcut?,
                                     translate: @MainActor (UInt32) -> String? = KeyNames.layoutCharacter)
        -> (key: String, modifiers: NSEvent.ModifierFlags)? {
        guard let shortcut else { return nil }
        let name = KeyNames.name(for: shortcut.keyCode, translate: translate)
        guard name.count == 1, let scalar = name.unicodeScalars.first,
              CharacterSet.alphanumerics.contains(scalar) else { return nil }
        var flags: NSEvent.ModifierFlags = []
        if shortcut.modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if shortcut.modifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if shortcut.modifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if shortcut.modifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return (name.lowercased(), flags)
    }

    private static func apps(_ count: Int) -> String {
        count == 1 ? "1 app" : "\(count) apps"
    }
}
