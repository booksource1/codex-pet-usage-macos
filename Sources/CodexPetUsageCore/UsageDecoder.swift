import Foundation

public enum UsageDecoder {
    public static func decode(
        data: Data,
        source: UsageSource,
        now: Date = Date()
    ) throws -> UsageSnapshot? {
        let object = try JSONSerialization.jsonObject(with: data)
        guard
            let root = object as? [String: Any],
            let rate = firstDictionary(root["rate_limit"], root["rate_limits"])
        else {
            return nil
        }

        let primary = firstDictionary(rate["primary_window"], rate["primary"])
        let secondary = firstDictionary(rate["secondary_window"], rate["secondary"])
        let primaryRemaining = remaining(in: primary)
        let secondaryRemaining = remaining(in: secondary)
        guard primaryRemaining != nil || secondaryRemaining != nil else {
            return nil
        }

        return UsageSnapshot(
            available: true,
            source: source,
            primaryRemaining: primaryRemaining,
            secondaryRemaining: secondaryRemaining,
            primaryResetAt: resetDate(in: primary, now: now),
            secondaryResetAt: resetDate(in: secondary, now: now),
            primaryWindowSeconds: windowSeconds(in: primary),
            secondaryWindowSeconds: windowSeconds(in: secondary),
            observedAt: now
        )
    }

    private static func firstDictionary(_ values: Any?...) -> [String: Any]? {
        for value in values {
            if let dictionary = value as? [String: Any] {
                return dictionary
            }
        }
        return nil
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber {
            return value.doubleValue
        }
        if let value = value as? String {
            return Double(value)
        }
        return nil
    }

    private static func remaining(in bucket: [String: Any]?) -> Double? {
        guard let bucket else { return nil }
        let value: Double?
        if let direct = number(bucket["remaining_percent"]) {
            value = direct
        } else if let used = number(bucket["used_percent"]) {
            value = 100 - used
        } else {
            value = nil
        }
        return value.map { min(100, max(0, $0)) }
    }

    private static func windowSeconds(in bucket: [String: Any]?) -> Double? {
        guard let bucket else { return nil }
        return number(bucket["limit_window_seconds"] ?? bucket["window_seconds"])
    }

    private static func resetDate(in bucket: [String: Any]?, now: Date) -> Date? {
        guard let bucket else { return nil }
        if let seconds = number(bucket["reset_after_seconds"]) {
            return now.addingTimeInterval(seconds)
        }
        if let seconds = number(bucket["seconds_until_reset"]) {
            return now.addingTimeInterval(seconds)
        }

        for key in ["reset_at", "resets_at", "reset_time", "expires_at", "window_reset_at"] {
            guard let value = bucket[key] else { continue }
            if let seconds = number(value) {
                return Date(timeIntervalSince1970: seconds)
            }
            if let text = value as? String {
                if let date = isoDate(from: text) {
                    return date
                }
            }
        }
        return nil
    }

    private static func isoDate(from text: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: text) {
            return date
        }
        if let date = ISO8601DateFormatter().date(from: text) {
            return date
        }

        let formats = [
            "yyyy-MM-dd HH:mm:ss Z",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy/M/d H:mm:ss Z",
            "yyyy/M/d H:mm:ss",
            "M/d/yyyy h:mm:ss a Z",
            "M/d/yyyy h:mm:ss a",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.dateFormat = format
            formatter.isLenient = false
            if let date = formatter.date(from: text) {
                return date
            }
        }
        return nil
    }
}

public func formatDuration(resetAt: Date?, now: Date = Date()) -> String {
    guard let resetAt else { return "--" }
    let seconds = Int(max(0, ceil(resetAt.timeIntervalSince(now))))
    if seconds >= 86_400 {
        return "\(seconds / 86_400)天 \((seconds % 86_400) / 3_600)小时"
    }
    if seconds >= 3_600 {
        return "\(seconds / 3_600)小时 \((seconds % 3_600) / 60)分钟"
    }
    if seconds >= 60 {
        return "\(seconds / 60)分钟 \(seconds % 60)秒"
    }
    return "\(seconds)秒"
}
