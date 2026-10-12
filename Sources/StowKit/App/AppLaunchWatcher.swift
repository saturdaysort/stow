import AppKit

/// Reports app launches and quits by watching `NSWorkspace.runningApplications` with KVO.
///
/// On macOS 27.2, `NSWorkspace.didLaunchApplicationNotification` is not posted for agent
/// (LSUIElement) or accessory apps, which covers most menu bar apps (Tailscale, Tiny Ipsum,
/// Creative Cloud, Nightfall). KVO on `runningApplications` sees every launch, delivered on
/// the main thread. Measured 2026-10-12 in the code review (finding 1).
@MainActor
public final class AppLaunchWatcher: NSObject {
    public enum Change: Equatable, Sendable {
        case launched
        case quit
    }

    private let source: NSObject
    private let keyPath = "runningApplications"
    private let onChange: @MainActor (Change) -> Void
    private var isObserving = false

    public init(source: NSObject = NSWorkspace.shared, onChange: @escaping @MainActor (Change) -> Void) {
        self.source = source
        self.onChange = onChange
    }

    public func start() {
        guard !isObserving else { return }
        source.addObserver(self, forKeyPath: keyPath, options: [.new], context: nil)
        isObserving = true
    }

    public func stop() {
        guard isObserving else { return }
        source.removeObserver(self, forKeyPath: keyPath)
        isObserving = false
    }

    override public nonisolated func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                                  change: [NSKeyValueChangeKey: Any]?,
                                                  context: UnsafeMutableRawPointer?) {
        guard let raw = change?[.kindKey] as? UInt, let kind = NSKeyValueChange(rawValue: raw) else { return }
        // A wholesale replacement can hide a launch, so it counts as one (a refresh is harmless).
        let reported: Change = kind == .removal ? .quit : .launched
        if Thread.isMainThread {
            MainActor.assumeIsolated { self.onChange(reported) }
        } else {
            DispatchQueue.main.async { self.onChange(reported) }
        }
    }
}
