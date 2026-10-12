import AppKit
import Carbon.HIToolbox

public enum ShortcutError: Error, Equatable, LocalizedError {
    case inUse
    case failed(Int32)

    public var errorDescription: String? {
        switch self {
        case .inUse: "That shortcut is used by another app"
        case .failed(let status): "Couldn't register that shortcut (error \(status))"
        }
    }
}

/// Registers one system-wide hot key. Injected so tests never grab real key combinations.
@MainActor public protocol HotKeyRegistering: AnyObject {
    var onPress: (@MainActor () -> Void)? { get set }
    /// Replaces any current registration. Throws `ShortcutError.inUse` when another app owns it.
    func register(_ shortcut: Shortcut) throws
    func unregister()
}

/// Carbon's RegisterEventHotKey: global, and needs no Input Monitoring permission (spec 6.6).
@MainActor public final class CarbonHotKey: HotKeyRegistering {
    public var onPress: (@MainActor () -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private static let signature: OSType = 0x53544F57   // 'STOW'

    public init() {}

    public func register(_ shortcut: Shortcut) throws {
        installHandlerIfNeeded()
        unregister()
        let id = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else {
            hotKeyRef = nil
            throw status == OSStatus(eventHotKeyExistsErr) ? ShortcutError.inUse : ShortcutError.failed(status)
        }
    }

    public func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let hotKey = Unmanaged<CarbonHotKey>.fromOpaque(userData).takeUnretainedValue()
            // Carbon delivers hot key events on the main thread.
            MainActor.assumeIsolated { hotKey.onPress?() }
            return noErr
        }, 1, &spec, context, &handlerRef)
    }
}

/// Keeps the saved shortcut registered, and swaps it safely (spec 6.6).
@MainActor public final class ShortcutController {
    public private(set) var lastError: String?
    private let registrar: any HotKeyRegistering
    private let preferences: Preferences

    public init(registrar: any HotKeyRegistering, preferences: Preferences,
                onPress: @escaping @MainActor () -> Void) {
        self.registrar = registrar
        self.preferences = preferences
        registrar.onPress = onPress
    }

    /// Registers the saved shortcut at launch.
    public func start() {
        guard let shortcut = preferences.shortcut else { return }
        do {
            try registrar.register(shortcut)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Tries a new shortcut; nil clears it. On failure the previous shortcut stays
    /// registered and saved, and `lastError` says why.
    @discardableResult
    public func apply(_ shortcut: Shortcut?) -> Bool {
        guard let shortcut else {
            registrar.unregister()
            preferences.shortcut = nil
            lastError = nil
            return true
        }
        let previous = preferences.shortcut
        do {
            try registrar.register(shortcut)
            preferences.shortcut = shortcut
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            if let previous { try? registrar.register(previous) }
            return false
        }
    }
}
