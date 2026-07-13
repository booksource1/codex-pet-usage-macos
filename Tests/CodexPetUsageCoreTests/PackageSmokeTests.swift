import Testing
@testable import CodexPetUsageCore

@Suite struct PackageSmokeTests {
    @Test func defaultsMatchJimmyReference() {
        #expect(OverlayDefaults.usagePollSeconds == 30)
        #expect(OverlayDefaults.petPollMilliseconds == 100)
        #expect(OverlayDefaults.hoverPadding == 24)
        #expect(OverlayDefaults.hoverShowSeconds == 10)
    }
}
