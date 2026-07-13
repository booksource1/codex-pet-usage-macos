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

let codexStateReaderTests: [TestCase] = [
    TestCase(name: "openPetProducesGlobalTopLeftAndAppKitRects") {
        let pet = CodexStateReader.decode(data: openPetState, primaryMaxY: 1080)
        try expect(pet?.topLeftRect == CGRect(x: 1775, y: 13, width: 77, height: 83), "top-left pet rect should match Codex state")
        try expect(pet?.appKitRect == CGRect(x: 1775, y: 984, width: 77, height: 83), "AppKit rect should flip around primary top edge")
        try expect(pet?.displayTopLeftRect == CGRect(x: 0, y: 0, width: 1920, height: 1080), "display bounds should decode")
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
