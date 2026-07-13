import Foundation
import CodexPetUsageCore

let overlayPresentationTests: [TestCase] = [
    TestCase(name: "availablePresentationMatchesReferenceStrings") {
        let now = fixedDate()
        let snapshot = UsageSnapshot(
            available: true,
            source: .test,
            primaryRemaining: 62.6,
            secondaryRemaining: 48.4,
            primaryResetAt: now.addingTimeInterval(90),
            secondaryResetAt: now.addingTimeInterval(120),
            observedAt: now
        )

        let model = OverlayPresentation.make(snapshot: snapshot, now: now)
        try expect(model.title == "Codex 用量", "title should match reference")
        try expect(model.primary == "5小时 剩余 63% · 1分钟 30秒后刷新", "primary line should match reference")
        try expect(model.secondary == "7天 剩余 48% · 2分钟 0秒后刷新", "secondary line should match reference")
        try expect(model.status == "来源 test · 12:00:00", "status should match reference")
        try expect(model.primaryPercent == 62.6, "primary arc should retain its percentage")
        try expect(model.secondaryPercent == 48.4, "secondary arc should retain its percentage")
    },
    TestCase(name: "unavailablePresentationMatchesReferenceStrings") {
        let model = OverlayPresentation.make(snapshot: .unavailable(now: fixedDate()), now: fixedDate())
        try expect(model.title == "Codex 用量", "unavailable title should remain visible")
        try expect(model.primary == "5小时 用量暂不可用", "primary unavailable line should match reference")
        try expect(model.secondary == "7天 用量暂不可用", "secondary unavailable line should match reference")
        try expect(model.status == "等待实时用量或本地日志", "waiting status should match reference")
        try expect(model.primaryPercent == 0, "missing primary usage should draw no arc")
        try expect(model.secondaryPercent == 0, "missing secondary usage should draw no arc")
    },
]
