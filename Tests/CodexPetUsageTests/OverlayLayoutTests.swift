import CoreGraphics
import Foundation
import CodexPetUsageCore

private func layoutPet(x: CGFloat, width: CGFloat = 80, height: CGFloat = 80, displayWidth: CGFloat = 1000) -> PetGeometry {
    let topLeft = CGRect(x: x, y: 100, width: width, height: height)
    return PetGeometry(
        topLeftRect: topLeft,
        appKitRect: CGRect(x: x, y: 900, width: width, height: height),
        displayTopLeftRect: CGRect(x: 0, y: 0, width: displayWidth, height: 1080)
    )
}

let overlayLayoutTests: [TestCase] = [
    TestCase(name: "layoutUsesExactReferenceDimensions") {
        let layout = OverlayLayout.compute(pet: layoutPet(x: 100), primaryMaxY: 1080)
        try expect(layout.ringSize == 132, "ring size should be pet max dimension plus 52")
        try expect(layout.windowFrame.size == CGSize(width: 364, height: 132), "window should include ring gap and 222-point card")
        try expect(layout.outerRadius == 59, "outer radius should subtract seven")
        try expect(layout.innerRadius == 46, "inner radius should be thirteen smaller")
        try expect(layout.cardFrame.size == CGSize(width: 222, height: 88), "card should match reference")
        try expect(layout.cardFrame.minY == 22, "card should be vertically centered")
    },
    TestCase(name: "layoutPlacesCardOnRightWhenThereIsRoom") {
        let layout = OverlayLayout.compute(pet: layoutPet(x: 100), primaryMaxY: 1080)
        try expect(!layout.placesCardOnLeft, "card should remain on right")
        try expect(layout.ringCenter.x == 66, "right layout ring center should be local half-size")
        try expect(layout.cardFrame.minX == 142, "right card should follow ten-point gap")
    },
    TestCase(name: "layoutPlacesCardOnLeftAtRightDisplayEdge") {
        let layout = OverlayLayout.compute(pet: layoutPet(x: 240, displayWidth: 320), primaryMaxY: 1080)
        try expect(layout.placesCardOnLeft, "card should avoid right edge")
        try expect(layout.cardFrame.minX == 0, "left card should start at window origin")
        try expect(layout.ringCenter.x == 298, "ring should follow left card plus gap")
    },
    TestCase(name: "layoutUsesMinimumRingSize") {
        let layout = OverlayLayout.compute(pet: layoutPet(x: 100, width: 20, height: 30), primaryMaxY: 1080)
        try expect(layout.ringSize == 104, "small pets should use minimum ring diameter")
        try expect(layout.windowFrame.height == 104, "window height should contain minimum ring")
    },
]
