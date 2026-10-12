import Testing
import ExamModeBridge
@testable import StowKit

@Suite struct ExamModeBridgeTests {
    @Test("MenuBarClientCore exposes the exam-mode classes on this Mac (macOS 27)")
    func bridgeIsAvailable() {
        #expect(SXExamModeIsAvailable())
    }

    @Test func bundleIdentifierIsStowsID() {
        #expect(StowKit.bundleIdentifier == "studio.longbrook.stow")
    }
}
