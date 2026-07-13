import CoreGraphics
import CodexPetUsageCore

let windowFrameMatcherTests: [TestCase] = [
    TestCase(name: "selectsLivePetWindowBySizeAndDistance") {
        let expected = CGRect(x: 1498, y: 0, width: 356, height: 320)
        let candidates = [
            CGRect(x: 0, y: 30, width: 1866, height: 1050),
            CGRect(x: 1498, y: 30, width: 356, height: 320),
        ]

        try expect(
            closestMatchingWindowFrame(expected: expected, candidates: candidates) == candidates[1],
            "the real pet window should be selected over the full Codex window"
        )
    },
    TestCase(name: "windowFrameSizeToleranceAppliesIndependently") {
        let expected = CGRect(x: 20, y: 30, width: 356, height: 320)
        let widthDifference = CGRect(x: 20, y: 30, width: 357, height: 320)
        let heightDifference = CGRect(x: 20, y: 30, width: 356, height: 319)

        try expect(
            closestMatchingWindowFrame(expected: expected, candidates: [widthDifference]) == widthDifference,
            "a one-point width difference should match"
        )
        try expect(
            closestMatchingWindowFrame(expected: expected, candidates: [heightDifference]) == heightDifference,
            "a one-point height difference should match"
        )
    },
    TestCase(name: "windowFrameSizeBeyondToleranceIsRejected") {
        let expected = CGRect(x: 20, y: 30, width: 356, height: 320)
        let candidates = [
            CGRect(x: 20, y: 30, width: 358, height: 320),
            CGRect(x: 20, y: 30, width: 356, height: 322),
        ]

        try expect(
            closestMatchingWindowFrame(expected: expected, candidates: candidates) == nil,
            "a candidate outside either size tolerance should not match"
        )
    },
    TestCase(name: "windowFrameMatchingSupportsNegativeOrigins") {
        let expected = CGRect(x: -500, y: -40, width: 356, height: 320)
        let candidate = CGRect(x: -498, y: -30, width: 356, height: 320)

        try expect(
            closestMatchingWindowFrame(expected: expected, candidates: [candidate]) == candidate,
            "negative global origins should be compared without clamping"
        )
    },
    TestCase(name: "windowFrameMatchingChoosesClosestOrigin") {
        let expected = CGRect(x: 100, y: 100, width: 356, height: 320)
        let closest = CGRect(x: 103, y: 104, width: 356, height: 320)
        let candidates = [
            CGRect(x: 90, y: 90, width: 356, height: 320),
            closest,
            CGRect(x: 120, y: 100, width: 356, height: 320),
        ]

        try expect(
            closestMatchingWindowFrame(expected: expected, candidates: candidates) == closest,
            "the closest matching origin should win"
        )
    },
    TestCase(name: "windowFrameMatchingPreservesInputOrderForEqualDistance") {
        let expected = CGRect(x: 100, y: 100, width: 356, height: 320)
        let first = CGRect(x: 90, y: 100, width: 356, height: 320)
        let second = CGRect(x: 110, y: 100, width: 356, height: 320)

        try expect(
            closestMatchingWindowFrame(expected: expected, candidates: [first, second]) == first,
            "equal-distance candidates should preserve input order"
        )
    },
    TestCase(name: "windowFrameMatchingReturnsNilForEmptyCandidates") {
        try expect(
            closestMatchingWindowFrame(
                expected: CGRect(x: 100, y: 100, width: 356, height: 320),
                candidates: []
            ) == nil,
            "an empty candidate list should not match"
        )
    },
]
