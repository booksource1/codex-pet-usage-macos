import CodexPetUsageCore

let packageSmokeTests: [TestCase] = [
    TestCase(name: "defaultsMatchJimmyReference") {
        try expect(OverlayDefaults.usagePollSeconds == 30, "usage poll must be 30 seconds")
        try expect(OverlayDefaults.petPollMilliseconds == 100, "pet poll must be 100 ms")
        try expect(OverlayDefaults.hoverPadding == 24, "hover padding must be 24 points")
        try expect(OverlayDefaults.hoverShowSeconds == 10, "hover display must be 10 seconds")
    },
]
