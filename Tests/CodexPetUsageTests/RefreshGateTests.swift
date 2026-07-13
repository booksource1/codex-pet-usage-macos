import CodexPetUsageCore

let refreshGateTests: [TestCase] = [
    TestCase(name: "refreshGatePreventsOverlapAndReopensAfterCompletion") {
        var gate = RefreshGate()
        try expect(gate.begin(), "first refresh should begin")
        try expect(!gate.begin(), "overlapping refresh should be rejected")
        gate.end()
        try expect(gate.begin(), "a later refresh should begin after completion")
    },
]
