@testable import StowKit

@MainActor final class FakeLoginItem: LoginItemControlling {
    var status: LoginItemStatus = .disabled
    var failNextChange = false
    private(set) var openedSettings = false

    func setEnabled(_ enabled: Bool) throws {
        if failNextChange {
            failNextChange = false
            throw FakeRefusal()
        }
        status = enabled ? .enabled : .disabled
    }

    func openSystemSettings() { openedSettings = true }
}
