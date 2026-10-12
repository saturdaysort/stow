import Foundation
import Testing
@testable import StowKit

@Suite struct AllowListTests {
    let own = "studio.longbrook.stow"

    @Test func runningMinusHiddenPlusSelfSorted() {
        let allowed = AllowList.compute(
            running: ["com.example.vpn", "com.apple.finder", "com.example.chat"],
            hidden: ["com.example.vpn"], own: own)
        #expect(allowed == ["com.apple.finder", "com.example.chat", "studio.longbrook.stow"])
    }

    @Test func stowIsNeverRemoved() {
        let allowed = AllowList.compute(running: ["com.apple.finder"], hidden: [own, "com.apple.finder"], own: own)
        #expect(allowed == [own])
    }

    @Test func duplicatesAndEmptyIDsAreDropped() {
        let allowed = AllowList.compute(running: ["com.a", "com.a", ""], hidden: [], own: own)
        #expect(allowed == ["com.a", own])
    }

    @Test func hiddenAppsThatAreNotRunningChangeNothing() {
        let allowed = AllowList.compute(running: ["com.a"], hidden: ["com.not.running"], own: own)
        #expect(allowed == ["com.a", own])
    }

    @Test func systemItemsKeepMacOSItems() {
        #expect(AllowList.systemItems == Array(0..<64))
    }

    @Test @MainActor func finderIsAlwaysAmongRunningApps() {
        #expect(RunningApps.bundleIDs().contains("com.apple.finder"))
    }

    @Test func installLocation() {
        #expect(InstallLocation.isExpected(URL(fileURLWithPath: "/Applications/Stow.app")))
        #expect(InstallLocation.isExpected(URL(fileURLWithPath: "/Applications/Stow.app/")))
        #expect(!InstallLocation.isExpected(URL(fileURLWithPath: "/Users/nate/Sites/stow/build/Stow.app")))
        #expect(!InstallLocation.isExpected(URL(fileURLWithPath: "/Applications/Utilities/Stow.app")))
        #expect(!InstallLocation.isExpected(URL(fileURLWithPath: "/Applications/Stow copy.app")))
    }
}
