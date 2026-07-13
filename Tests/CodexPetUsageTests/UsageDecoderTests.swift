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
    TestCase(name: "sevenDayBucketInPrimarySlotUsesDeclaredDuration") {
        let data = jsonData(#"{"rate_limit":{"primary_window":{"used_percent":23,"limit_window_seconds":604800}}}"#)
        let usage = try UsageDecoder.decode(data: data, source: .test, now: fixedDate())
        try expect(usage?.primaryRemaining == nil, "missing five-hour window must remain missing")
        try expectApproximately(usage?.secondaryRemaining, 77, "604800-second bucket must be seven-day usage")
        try expect(usage?.primaryWindowSeconds == nil, "missing five-hour duration must remain missing")
        try expectApproximately(usage?.secondaryWindowSeconds, 604_800, "seven-day duration must follow the bucket")
    },
    TestCase(name: "recognizedBucketsCanAppearInEitherSlot") {
        let data = jsonData(#"{"rate_limit":{"primary_window":{"remaining_percent":42,"limit_window_seconds":604800},"secondary_window":{"remaining_percent":61,"limit_window_seconds":18000}}}"#)
        let usage = try UsageDecoder.decode(data: data, source: .test, now: fixedDate())
        try expectApproximately(usage?.primaryRemaining, 61, "18000-second bucket must be five-hour usage")
        try expectApproximately(usage?.secondaryRemaining, 42, "604800-second bucket must be seven-day usage")
    },
    TestCase(name: "durationlessBucketsRetainLegacyPositions") {
        let data = jsonData(#"{"rate_limit":{"primary_window":{"remaining_percent":61},"secondary_window":{"remaining_percent":42}}}"#)
        let usage = try UsageDecoder.decode(data: data, source: .test, now: fixedDate())
        try expectApproximately(usage?.primaryRemaining, 61, "durationless primary remains five-hour")
        try expectApproximately(usage?.secondaryRemaining, 42, "durationless secondary remains seven-day")
    },
    TestCase(name: "declaredDurationDisablesPositionalInference") {
        let data = jsonData(#"{"rate_limit":{"primary_window":{"remaining_percent":77,"limit_window_seconds":604800},"secondary_window":{"remaining_percent":55,"limit_window_seconds":3600}}}"#)
        let usage = try UsageDecoder.decode(data: data, source: .test, now: fixedDate())
        try expect(usage?.primaryRemaining == nil, "unrecognized bucket must not be inferred as five-hour")
        try expectApproximately(usage?.secondaryRemaining, 77, "recognized seven-day bucket must survive")
    },
    TestCase(name: "remainingPercentAndAlternativeNamesAreAccepted") {
        let data = jsonData(#"{"rate_limits":{"primary":{"remaining_percent":12,"window_seconds":18000,"seconds_until_reset":60}}}"#)
        let usage = try UsageDecoder.decode(data: data, source: .test, now: fixedDate())
        try expectApproximately(usage?.primaryRemaining, 12, "remaining percent should be direct")
        try expectApproximately(usage?.primaryWindowSeconds, 18_000, "alternative window name should decode")
        try expect(usage?.primaryResetAt == fixedDate().addingTimeInterval(60), "alternative relative reset should decode")
    },
    TestCase(name: "nullPreferredAliasesFallThroughLikeReference") {
        let data = jsonData(#"{"rate_limit":null,"rate_limits":{"primary_window":null,"primary":{"remaining_percent":25,"limit_window_seconds":null,"window_seconds":18000}}}"#)
        let usage = try UsageDecoder.decode(data: data, source: .test, now: fixedDate())
        try expectApproximately(usage?.primaryRemaining, 25, "null preferred aliases should fall through to valid alternatives")
        try expectApproximately(usage?.primaryWindowSeconds, 18_000, "null preferred window seconds should fall through")
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
    TestCase(name: "fractionalISOResetMatchesReferenceDateParsing") {
        let data = jsonData(#"{"rate_limit":{"primary_window":{"remaining_percent":50,"reset_at":"2026-01-01T12:10:00.250Z"}}}"#)
        let usage = try UsageDecoder.decode(data: data, source: .test, now: fixedDate())
        try expect(
            usage?.primaryResetAt == Date(timeIntervalSince1970: 1_767_269_400.25),
            "fractional ISO reset should decode like DateTime.Parse"
        )
    },
    TestCase(name: "spaceSeparatedResetMatchesReferenceDateParsing") {
        let data = jsonData(#"{"rate_limit":{"primary_window":{"remaining_percent":50,"reset_at":"2026-01-01 12:10:00 +0000"}}}"#)
        let usage = try UsageDecoder.decode(data: data, source: .test, now: fixedDate())
        try expect(
            usage?.primaryResetAt == Date(timeIntervalSince1970: 1_767_269_400),
            "space-separated reset should decode like DateTime.Parse"
        )
    },
    TestCase(name: "twelveHourClockWithoutMeridiemMatchesReferenceParsing") {
        let data = jsonData(#"{"rate_limit":{"primary_window":{"remaining_percent":50,"reset_at":"1/1/2026 12:10:00"}}}"#)
        let usage = try UsageDecoder.decode(data: data, source: .test, now: fixedDate())
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let expected = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12, minute: 10))
        try expect(usage?.primaryResetAt == expected, "local numeric reset should decode like DateTime.Parse")
    },
    TestCase(name: "naturalLanguageResetMatchesReferenceParsing") {
        let data = jsonData(#"{"rate_limit":{"primary_window":{"remaining_percent":50,"reset_at":"January 1, 2026 12:10:00 PM"}}}"#)
        let usage = try UsageDecoder.decode(data: data, source: .test, now: fixedDate())
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let expected = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12, minute: 10))
        try expect(usage?.primaryResetAt == expected, "natural-language reset should decode like DateTime.Parse")
    },
    TestCase(name: "ambiguousNumericResetUsesLocaleDateOrder") {
        let data = jsonData(#"{"rate_limit":{"primary_window":{"remaining_percent":50,"reset_at":"1/2/2026 12:10:00"}}}"#)
        let monthFirst = try UsageDecoder.decode(
            data: data,
            source: .test,
            now: fixedDate(),
            locale: Locale(identifier: "en_PH")
        )
        let dayFirst = try UsageDecoder.decode(
            data: data,
            source: .test,
            now: fixedDate(),
            locale: Locale(identifier: "en_GB")
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let januarySecond = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 12, minute: 10))
        let februaryFirst = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 12, minute: 10))
        try expect(monthFirst?.primaryResetAt == januarySecond, "month-first locale should parse 1/2 as January 2")
        try expect(dayFirst?.primaryResetAt == februaryFirst, "day-first locale should parse 1/2 as February 1")
    },
    TestCase(name: "durationRoundsUpLikeReference") {
        try expect(formatDuration(resetAt: fixedDate().addingTimeInterval(60.1), now: fixedDate()) == "1分钟 1秒", "duration should ceil seconds")
        try expect(formatDuration(resetAt: fixedDate().addingTimeInterval(3_661), now: fixedDate()) == "1小时 1分钟", "hour format should match reference")
        try expect(formatDuration(resetAt: fixedDate().addingTimeInterval(90_000), now: fixedDate()) == "1天 1小时", "day format should match reference")
        try expect(formatDuration(resetAt: nil, now: fixedDate()) == "--", "missing reset should be unavailable")
    },
]
