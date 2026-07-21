import Foundation
import CodexPetUsageCore

private let openPetState = Data(#"""
{
  "electron-avatar-overlay-open": true,
  "electron-avatar-overlay-bounds": {
    "x": 1524, "y": 0, "width": 356, "height": 320,
    "mascot": {"left": 251, "top": 13, "width": 77, "height": 83},
    "displayBounds": {"x": 0, "y": 0, "width": 1920, "height": 1080}
  }
}
"""#.utf8)

private let staleOverlayState = Data(#"""
{
  "electron-avatar-overlay-open": true,
  "electron-avatar-overlay-bounds": {
    "x": 1498, "y": 0, "width": 356, "height": 320,
    "mascot": {"left": 248, "top": 87, "width": 80, "height": 87},
    "displayBounds": {"x": 0, "y": 0, "width": 1920, "height": 1080}
  }
}
"""#.utf8)

private let nestedDisplayState = Data(#"""
{
  "electron-avatar-overlay-open": true,
  "electron-avatar-overlay-bounds": {
    "x": 1746, "y": 165, "displayId": 3,
    "displayBounds": {"x": 0, "y": 0, "width": 1920, "height": 1080},
    "byDisplayId": {
      "3": {
        "displayId": 3, "x": 1746, "y": 165,
        "displayBounds": {"x": 0, "y": 0, "width": 1920, "height": 1080}
      },
      "23": {
        "displayId": 23, "x": 1564, "y": 87, "width": 356, "height": 320,
        "mascot": {"left": 243, "top": 63, "width": 113, "height": 122},
        "displayBounds": {"x": 0, "y": 0, "width": 1920, "height": 1080}
      },
      "42": {
        "displayId": 42, "x": 1472, "y": 0, "width": 356, "height": 320,
        "mascot": {"left": 248, "top": 31, "width": 80, "height": 87},
        "displayBounds": {"x": 0, "y": 0, "width": 1920, "height": 1080}
      }
    }
  }
}
"""#.utf8)

private let currentTopLevelPositionState = Data(#"""
{
  "electron-avatar-overlay-open": true,
  "electron-avatar-overlay-bounds": {
    "x": 1648.1875, "y": 876.81640625,
    "displayId": 3, "placement": "top-end",
    "displayBounds": {"x": 0, "y": 0, "width": 1920, "height": 1080},
    "byDisplayId": {
      "23": {
        "x": 1564, "y": 87, "width": 356, "height": 320,
        "mascot": {"left": 243, "top": 63, "width": 113, "height": 122}
      },
      "24": {
        "x": 1472, "y": 143, "width": 356, "height": 320,
        "mascot": {"left": 215, "top": 63, "width": 113, "height": 122}
      },
      "37": {
        "x": 1342, "y": 137, "width": 356, "height": 320,
        "mascot": {"left": 248, "top": 8, "width": 80, "height": 87}
      }
    }
  }
}
"""#.utf8)

let codexStateReaderTests: [TestCase] = [
    TestCase(name: "openPetProducesGlobalTopLeftAndAppKitRects") {
        let pet = CodexStateReader.decode(data: openPetState, primaryMaxY: 1080)
        try expect(pet?.topLeftRect == CGRect(x: 1775, y: 13, width: 77, height: 83), "top-left pet rect should match Codex state")
        try expect(pet?.appKitRect == CGRect(x: 1775, y: 984, width: 77, height: 83), "AppKit rect should flip around primary top edge")
        try expect(pet?.displayTopLeftRect == CGRect(x: 0, y: 0, width: 1920, height: 1080), "display bounds should decode")
        try expect(pet?.overlayTopLeftRect == CGRect(x: 1524, y: 0, width: 356, height: 320), "overlay frame should be retained")
    },
    TestCase(name: "nestedDisplayStateUsesCurrentTopLevelPosition") {
        let pet = CodexStateReader.decode(data: nestedDisplayState, primaryMaxY: 1080)
        try expect(pet?.topLeftRect == CGRect(x: 1746, y: 165, width: 80, height: 87), "current top-level position should become the pet rect")
        try expect(pet?.appKitRect == CGRect(x: 1746, y: 828, width: 80, height: 87), "current top-level pet should convert to AppKit coordinates")
        try expect(pet?.displayTopLeftRect == CGRect(x: 0, y: 0, width: 1920, height: 1080), "nested display bounds should decode")
        try expect(pet?.overlayTopLeftRect == nil, "historical nested geometry should not be used as the live overlay frame")
    },
    TestCase(name: "currentTopLevelPositionDoesNotUseHistoricalNestedGeometry") {
        let pet = CodexStateReader.decode(data: currentTopLevelPositionState, primaryMaxY: 1080)
        try expect(pet?.topLeftRect == CGRect(x: 1648.1875, y: 876.81640625, width: 80, height: 87), "current top-level position should anchor the current pet")
        try expect(pet?.appKitRect == CGRect(x: 1648.1875, y: 116.18359375, width: 80, height: 87), "current top-level pet should convert to AppKit coordinates")
    },
    TestCase(name: "liveOverlayOriginCorrectsStaleJSONGeometry") {
        guard let pet = CodexStateReader.decode(data: staleOverlayState, primaryMaxY: 1080) else {
            throw TestFailure(description: "open state should decode")
        }
        let liveFrame = CGRect(x: 1498, y: 30, width: 356, height: 320)
        let corrected = pet.corrected(liveOverlayFrame: liveFrame, primaryMaxY: 1080)
        let originalLayout = OverlayLayout.compute(pet: pet, primaryMaxY: 1080)
        let correctedLayout = OverlayLayout.compute(pet: corrected, primaryMaxY: 1080)

        try expect(corrected.topLeftRect == CGRect(x: 1746, y: 117, width: 80, height: 87), "live top-left delta should correct the pet frame")
        try expect(corrected.appKitRect == CGRect(x: 1746, y: 876, width: 80, height: 87), "AppKit conversion should happen after correction")
        try expect(corrected.displayTopLeftRect == pet.displayTopLeftRect, "display bounds should be preserved")
        try expect(corrected.overlayTopLeftRect == liveFrame, "corrected geometry should retain the live overlay frame")
        try expect(
            correctedLayout.windowFrame == originalLayout.windowFrame.offsetBy(dx: 0, dy: -30),
            "a 30-point top-left downward correction should shift the AppKit layout upward by 30 points"
        )
    },
    TestCase(name: "nilLiveOverlayFrameLeavesGeometryUnchanged") {
        guard let pet = CodexStateReader.decode(data: staleOverlayState, primaryMaxY: 1080) else {
            throw TestFailure(description: "open state should decode")
        }
        let unchanged = pet.corrected(liveOverlayFrame: nil, primaryMaxY: 1080)

        try expect(unchanged.topLeftRect == pet.topLeftRect, "nil live frame should preserve the top-left pet rect")
        try expect(unchanged.appKitRect == pet.appKitRect, "nil live frame should preserve the AppKit pet rect")
        try expect(unchanged.displayTopLeftRect == pet.displayTopLeftRect, "nil live frame should preserve display bounds")
        try expect(unchanged.overlayTopLeftRect == pet.overlayTopLeftRect, "nil live frame should preserve the JSON overlay frame")
    },
    TestCase(name: "horizontalLiveOverlayDeltaMovesPetAndLayout") {
        guard let pet = CodexStateReader.decode(data: staleOverlayState, primaryMaxY: 1080) else {
            throw TestFailure(description: "open state should decode")
        }
        let corrected = pet.corrected(
            liveOverlayFrame: CGRect(x: 1513, y: 0, width: 356, height: 320),
            primaryMaxY: 1080
        )
        let originalLayout = OverlayLayout.compute(pet: pet, primaryMaxY: 1080)
        let correctedLayout = OverlayLayout.compute(pet: corrected, primaryMaxY: 1080)

        try expect(corrected.topLeftRect.minX == pet.topLeftRect.minX + 15, "pet x should move by the live overlay delta")
        try expect(corrected.appKitRect.minX == pet.appKitRect.minX + 15, "AppKit pet x should move by the live overlay delta")
        try expect(correctedLayout.windowFrame.minX == originalLayout.windowFrame.minX + 15, "layout x should move by the live overlay delta")
    },
    TestCase(name: "closedOverlayReturnsNil") {
        let data = Data(#"{"electron-avatar-overlay-open":false,"electron-avatar-overlay-bounds":{"mascot":{"left":0,"top":0,"width":10,"height":10}}}"#.utf8)
        try expect(CodexStateReader.decode(data: data, primaryMaxY: 1080) == nil, "closed pet should be unavailable")
    },
    TestCase(name: "missingMascotAndMalformedStateReturnNil") {
        let missing = Data(#"{"electron-avatar-overlay-open":true,"electron-avatar-overlay-bounds":{}}"#.utf8)
        try expect(CodexStateReader.decode(data: missing, primaryMaxY: 1080) == nil, "missing mascot should return nil")
        try expect(CodexStateReader.decode(data: Data("{".utf8), primaryMaxY: 1080) == nil, "partial JSON should return nil")
    },
    TestCase(name: "missingDisplayBoundsUseReferenceDefaults") {
        let data = Data(#"{"electron-avatar-overlay-open":true,"electron-avatar-overlay-bounds":{"x":10,"y":20,"mascot":{"left":1,"top":2,"width":30,"height":40}}}"#.utf8)
        let pet = CodexStateReader.decode(data: data, primaryMaxY: 1080)
        try expect(pet?.displayTopLeftRect == CGRect(x: 0, y: 0, width: 1920, height: 1080), "missing display bounds should use Jimmy defaults")
        try expect(pet?.overlayTopLeftRect == nil, "missing overlay dimensions should not synthesize an overlay frame")
        let unchanged = pet?.corrected(
            liveOverlayFrame: CGRect(x: 100, y: 100, width: 356, height: 320),
            primaryMaxY: 1080
        )
        try expect(unchanged?.topLeftRect == pet?.topLeftRect, "a missing JSON overlay frame should prevent correction")
        try expect(unchanged?.appKitRect == pet?.appKitRect, "a missing JSON overlay frame should preserve AppKit geometry")
    },
    TestCase(name: "negativeDisplayOriginsArePreserved") {
        let data = Data(#"{"electron-avatar-overlay-open":true,"electron-avatar-overlay-bounds":{"x":-500,"y":80,"mascot":{"left":20,"top":30,"width":50,"height":60},"displayBounds":{"x":-1920,"y":0,"width":1920,"height":1080}}}"#.utf8)
        let pet = CodexStateReader.decode(data: data, primaryMaxY: 1080)
        try expect(pet?.topLeftRect.origin.x == -480, "negative screen x should be preserved")
        try expect(pet?.displayTopLeftRect.origin.x == -1920, "negative display origin should be preserved")
    },
    TestCase(name: "fileReadRaceReturnsNilInsteadOfThrowing") {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("partial".utf8).write(to: directory.appendingPathComponent(".codex-global-state.json"))
        try expect(CodexStateReader.read(codexHome: directory, primaryMaxY: 1080) == nil, "partially-written state should recover")
    },
]
