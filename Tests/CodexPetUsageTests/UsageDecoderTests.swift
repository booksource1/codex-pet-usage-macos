import Foundation
import CodexPetUsageCore

private func jsonData(_ string: String) -> Data {
    Data(string.utf8)
}

let usageDecoderTests: [TestCase] = [
    TestCase(name: "usedPercentBecomesRemaining") {
        let data = jsonData(#"{"rate_limit":{"primary_window":{"used_percent":37,"limit_window_seconds":18000,"reset_after_seconds":90},"secondary_window":{"used_percent":52,"limit_window_seconds":604800,"reset_after_seconds":120}}}"#)
        let usage = try UsageDecoder.decode(data: data, source: .test, now: fixedDate())
        try expect(usage != nil, "valid usage should decode")
        try expectApproximately(usage?.primaryRemaining, 63, "primary used percent should invert")
        try expectApproximately(usage?.secondaryRemaining, 48, "secondary used percent should invert")
        try expectApproximately(usage?.primaryWindowSeconds, 18_000, "primary window seconds should decode")
        try expectApproximately(usage?.secondaryWindowSeconds, 604_800, "secondary window seconds should decode")
        try expect(usage?.primaryResetAt == fixedDate().addingTimeInterval(90), "relative reset should use supplied now")
    },
    TestCase(name: "remainingPercentAndAlternativeNamesAreAccepted") {
        let data = jsonData(#"{"rate_limits":{"primary":{"remaining_percent":12,"window_seconds":18000,"seconds_until_reset":60}}}"#)
        let usage = try UsageDecoder.decode(data: data, source: .test, now: fixedDate())
        try expectApproximately(usage?.primaryRemaining, 12, "remaining percent should be direct")
        try expectApproximately(usage?.primaryWindowSeconds, 18_000, "alternative window name should decode")
        try expect(usage?.primaryResetAt == fixedDate().addingTimeInterval(60), "alternative relative reset should decode")
    },
    TestCase(name: "percentagesClampToZeroThroughOneHundred") {
        let data = jsonData(#"{"rate_limit":{"primary_window":{"remaining_percent":-4},"secondary_window":{"remaining_percent":140}}}"#)
        let usage = try UsageDecoder.decode(data: data, source: .test, now: fixedDate())
        try expectApproximately(usage?.primaryRemaining, 0, "negative remaining should clamp")
        try expectApproximately(usage?.secondaryRemaining, 100, "large remaining should clamp")
    },
    TestCase(name: "absentWindowsReturnNil") {
        let usage = try UsageDecoder.decode(data: jsonData(#"{}"#), source: .test, now: fixedDate())
        try expect(usage == nil, "missing rate limits should return nil")
    },
    TestCase(name: "resetVariantsNormalize") {
        let unix = fixedDate().addingTimeInterval(300).timeIntervalSince1970
        let numeric = jsonData("{\"rate_limit\":{\"primary_window\":{\"remaining_percent\":50,\"reset_at\":\(Int(unix))}}}")
        let numericUsage = try UsageDecoder.decode(data: numeric, source: .test, now: fixedDate())
        try expect(numericUsage?.primaryResetAt == Date(timeIntervalSince1970: unix), "Unix reset should decode")

        let iso = jsonData(#"{"rate_limit":{"primary_window":{"remaining_percent":50,"expires_at":"2026-01-01T12:10:00Z"}}}"#)
        let isoUsage = try UsageDecoder.decode(data: iso, source: .test, now: fixedDate())
        try expect(isoUsage?.primaryResetAt == Date(timeIntervalSince1970: 1_767_269_400), "ISO reset should decode")
    },
    TestCase(name: "durationRoundsUpLikeReference") {
        try expect(formatDuration(resetAt: fixedDate().addingTimeInterval(60.1), now: fixedDate()) == "1分钟 1秒", "duration should ceil seconds")
        try expect(formatDuration(resetAt: fixedDate().addingTimeInterval(3_661), now: fixedDate()) == "1小时 1分钟", "hour format should match reference")
        try expect(formatDuration(resetAt: fixedDate().addingTimeInterval(90_000), now: fixedDate()) == "1天 1小时", "day format should match reference")
        try expect(formatDuration(resetAt: nil, now: fixedDate()) == "--", "missing reset should be unavailable")
    },
]
