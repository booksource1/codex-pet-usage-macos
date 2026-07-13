import Foundation

public struct OverlayPresentation: Sendable, Equatable {
    public let title: String
    public let primary: String
    public let secondary: String
    public let status: String
    public let primaryPercent: Double
    public let secondaryPercent: Double

    public static func make(snapshot: UsageSnapshot, now: Date = Date()) -> OverlayPresentation {
        guard snapshot.available else {
            return OverlayPresentation(
                title: "Codex 用量",
                primary: "5小时 用量暂不可用",
                secondary: "7天 用量暂不可用",
                status: "等待实时用量或本地日志",
                primaryPercent: 0,
                secondaryPercent: 0
            )
        }

        let primaryPercent = snapshot.primaryRemaining.map(clamped) ?? 0
        let secondaryPercent = snapshot.secondaryRemaining.map(clamped) ?? 0
        let primaryText = snapshot.primaryRemaining.map { "\(integer(clamped($0)))%" } ?? "--"
        let secondaryText = snapshot.secondaryRemaining.map { "\(integer(clamped($0)))%" } ?? "--"
        let primaryReset = snapshot.primaryRemaining == nil
            ? "--"
            : formatDuration(resetAt: snapshot.primaryResetAt, now: now)
        let secondaryReset = snapshot.secondaryRemaining == nil
            ? "--"
            : formatDuration(resetAt: snapshot.secondaryResetAt, now: now)
        return OverlayPresentation(
            title: "Codex 用量",
            primary: "5小时 剩余 \(primaryText) · \(primaryReset)后刷新",
            secondary: "7天 剩余 \(secondaryText) · \(secondaryReset)后刷新",
            status: "来源 \(snapshot.source.rawValue) · \(clockTime(snapshot.observedAt))",
            primaryPercent: primaryPercent,
            secondaryPercent: secondaryPercent
        )
    }

    private static func clamped(_ value: Double) -> Double {
        min(100, max(0, value))
    }

    private static func integer(_ value: Double) -> String {
        String(format: "%.0f", locale: Locale(identifier: "zh_CN"), value)
    }

    private static func clockTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

public func usageLogLine(_ snapshot: UsageSnapshot) -> String {
    let primary = snapshot.primaryRemaining.map { String(Int($0.rounded())) } ?? "--"
    let secondary = snapshot.secondaryRemaining.map { String(Int($0.rounded())) } ?? "--"
    return "Usage updated: source=\(snapshot.source.rawValue), 5h=\(primary), 7d=\(secondary)"
}
