import Foundation
@testable import StowKit

struct FakeRefusal: LocalizedError {
    var errorDescription: String? { "refused" }
}

/// Records every activate and invalidate, in order. Completes immediately unless
/// `holdCompletions` is set; held completions run when the test calls `releasePending()`.
@MainActor final class FakeRestriction: MenuBarRestriction {
    enum Event: Equatable {
        case activate([String])
        case invalidate(Int)
    }

    @MainActor final class Token: RestrictionToken {
        let id: Int
        private weak var owner: FakeRestriction?
        private(set) var isInvalidated = false

        init(id: Int, owner: FakeRestriction) {
            self.id = id
            self.owner = owner
        }

        func invalidate() {
            guard !isInvalidated else { return }
            isInvalidated = true
            owner?.events.append(.invalidate(id))
        }
    }

    var isAvailable = true
    var refuse = false
    var holdCompletions = false
    var events: [Event] = []
    private(set) var lastSystemItems: [Int] = []
    private var pending: [(refused: Bool, completion: @MainActor (Result<any RestrictionToken, any Error>) -> Void)] = []
    private var tokens: [Token] = []
    private var nextID = 1

    var liveTokens: [Token] { tokens.filter { !$0.isInvalidated } }
    var activations: [[String]] { events.compactMap { if case .activate(let ids) = $0 { ids } else { nil } } }

    func activate(allowing bundleIDs: [String], systemItems: [Int],
                  completion: @escaping @MainActor (Result<any RestrictionToken, any Error>) -> Void) {
        events.append(.activate(bundleIDs))
        lastSystemItems = systemItems
        if holdCompletions {
            pending.append((refused: refuse, completion: completion))
        } else {
            complete(completion, refused: refuse)
        }
    }

    func releasePending() {
        let waiting = pending
        pending.removeAll()
        for entry in waiting { complete(entry.completion, refused: entry.refused) }
    }

    private func complete(_ completion: @MainActor (Result<any RestrictionToken, any Error>) -> Void, refused: Bool) {
        if refused {
            completion(.failure(FakeRefusal()))
            return
        }
        let token = Token(id: nextID, owner: self)
        nextID += 1
        tokens.append(token)
        completion(.success(token))
    }
}
