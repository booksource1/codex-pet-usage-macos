import CoreGraphics
import Foundation
import CodexPetUsageCore

private func hoverPet() -> PetGeometry {
    PetGeometry(
        topLeftRect: CGRect(x: 10, y: 20, width: 30, height: 40),
        appKitRect: CGRect(x: 10, y: 20, width: 30, height: 40),
        displayTopLeftRect: CGRect(x: 0, y: 0, width: 1920, height: 1080)
    )
}

let hoverStateTests: [TestCase] = [
    TestCase(name: "hitTestingMatchesReferenceIncludingPadding") {
        let rect = CGRect(x: 10, y: 20, width: 30, height: 40)
        try expect(pointIsInside(CGPoint(x: 15, y: 25), rect: rect), "interior point should hit")
        try expect(!pointIsInside(CGPoint(x: 50, y: 25), rect: rect), "outside point should miss")
        try expect(pointIsInside(CGPoint(x: 50, y: 25), rect: rect, padding: 10), "padding should catch nearby point")
    },
    TestCase(name: "firstEntryShowsForTenSeconds") {
        var state = HoverState()
        let now = fixedDate()
        try expect(state.update(pet: hoverPet(), cursor: CGPoint(x: 15, y: 25), now: now), "first entry should show")
        try expect(state.update(pet: hoverPet(), cursor: CGPoint(x: 15, y: 25), now: now.addingTimeInterval(9)), "overlay should remain at nine seconds")
        try expect(!state.update(pet: hoverPet(), cursor: CGPoint(x: 15, y: 25), now: now.addingTimeInterval(11)), "overlay should expire after ten seconds")
    },
    TestCase(name: "stayingOnPetDoesNotExtendDisplay") {
        var state = HoverState()
        let now = fixedDate()
        _ = state.update(pet: hoverPet(), cursor: CGPoint(x: 15, y: 25), now: now)
        let firstUntil = state.showUntil
        _ = state.update(pet: hoverPet(), cursor: CGPoint(x: 15, y: 25), now: now.addingTimeInterval(5))
        try expect(state.showUntil == firstUntil, "staying should not extend")
    },
    TestCase(name: "reentryWhileVisibleDoesNotExtendDisplay") {
        var state = HoverState()
        let now = fixedDate()
        _ = state.update(pet: hoverPet(), cursor: CGPoint(x: 15, y: 25), now: now)
        let firstUntil = state.showUntil
        _ = state.update(pet: hoverPet(), cursor: CGPoint(x: 100, y: 100), now: now.addingTimeInterval(2))
        _ = state.update(pet: hoverPet(), cursor: CGPoint(x: 15, y: 25), now: now.addingTimeInterval(5))
        try expect(state.showUntil == firstUntil, "active reentry should not extend")
    },
    TestCase(name: "reentryAfterExpiryStartsNewDisplay") {
        var state = HoverState()
        let now = fixedDate()
        _ = state.update(pet: hoverPet(), cursor: CGPoint(x: 15, y: 25), now: now)
        let firstUntil = state.showUntil
        _ = state.update(pet: hoverPet(), cursor: CGPoint(x: 100, y: 100), now: now.addingTimeInterval(11))
        try expect(state.update(pet: hoverPet(), cursor: CGPoint(x: 15, y: 25), now: now.addingTimeInterval(12)), "expired reentry should show")
        try expect(state.showUntil! > firstUntil!, "expired reentry should set a later deadline")
    },
    TestCase(name: "missingPetClearsTriggerStateButKeepsVisibilityMarker") {
        var state = HoverState()
        _ = state.update(pet: hoverPet(), cursor: CGPoint(x: 15, y: 25), now: fixedDate())
        try expect(!state.update(pet: nil, cursor: .zero, now: fixedDate().addingTimeInterval(1)), "missing pet should hide")
        try expect(state.showUntil == nil, "missing pet should clear deadline")
        try expect(!state.cursorWasInPet, "missing pet should clear cursor history")
        try expect(state.overlayWasVisible, "reference keeps the prior visibility marker for later expiry logging")
    },
]
