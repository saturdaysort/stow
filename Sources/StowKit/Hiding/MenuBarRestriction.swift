import Foundation
import ExamModeBridge

/// A live restriction. Invalidating it brings every hidden icon back.
@MainActor public protocol RestrictionToken: AnyObject {
    func invalidate()
}

/// Something that can restrict the menu bar to an allow-list of apps.
@MainActor public protocol MenuBarRestriction: AnyObject {
    var isAvailable: Bool { get }
    func activate(allowing bundleIDs: [String], systemItems: [Int],
                  completion: @escaping @MainActor (Result<any RestrictionToken, any Error>) -> Void)
}

/// macOS 27's exam-mode allow-list, through ExamModeBridge.
@MainActor public final class ExamModeRestriction: MenuBarRestriction {
    public init() {}

    public var isAvailable: Bool { SXExamModeIsAvailable() }

    public func activate(allowing bundleIDs: [String], systemItems: [Int],
                         completion: @escaping @MainActor (Result<any RestrictionToken, any Error>) -> Void) {
        SXExamModeActivate(systemItems.map { NSNumber(value: $0) }, bundleIDs) { assertion, error in
            // The bridge always calls back on the main queue.
            MainActor.assumeIsolated {
                if error == nil, let assertion {
                    completion(.success(ExamModeToken(assertion as AnyObject)))
                } else {
                    completion(.failure(error ?? ExamModeError.noAssertion))
                }
            }
        }
    }
}

enum ExamModeError: LocalizedError {
    case noAssertion
    var errorDescription: String? { "macOS didn't confirm the menu bar restriction." }
}

@MainActor final class ExamModeToken: RestrictionToken {
    private var assertion: AnyObject?

    init(_ assertion: AnyObject) { self.assertion = assertion }

    func invalidate() {
        guard let assertion else { return }
        SXExamModeInvalidate(assertion)
        self.assertion = nil
    }
}
