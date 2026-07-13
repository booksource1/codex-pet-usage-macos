import Foundation

public enum OverlayDefaults {
    public static let usagePollSeconds: TimeInterval = 30
    public static let petPollMilliseconds = 100
    public static let hoverPadding: CGFloat = 24
    public static let hoverShowSeconds: TimeInterval = 10
}

public enum UsageSource: String, Sendable, Equatable {
    case live
    case log
    case test
    case none
}

public struct UsageSnapshot: Sendable, Equatable {
    public let available: Bool
    public let source: UsageSource
    public let primaryRemaining: Double?
    public let secondaryRemaining: Double?
    public let primaryResetAt: Date?
    public let secondaryResetAt: Date?
    public let primaryWindowSeconds: Double?
    public let secondaryWindowSeconds: Double?
    public let observedAt: Date

    public init(
        available: Bool,
        source: UsageSource,
        primaryRemaining: Double? = nil,
        secondaryRemaining: Double? = nil,
        primaryResetAt: Date? = nil,
        secondaryResetAt: Date? = nil,
        primaryWindowSeconds: Double? = nil,
        secondaryWindowSeconds: Double? = nil,
        observedAt: Date
    ) {
        self.available = available
        self.source = source
        self.primaryRemaining = primaryRemaining
        self.secondaryRemaining = secondaryRemaining
        self.primaryResetAt = primaryResetAt
        self.secondaryResetAt = secondaryResetAt
        self.primaryWindowSeconds = primaryWindowSeconds
        self.secondaryWindowSeconds = secondaryWindowSeconds
        self.observedAt = observedAt
    }

    public static func unavailable(now: Date) -> UsageSnapshot {
        UsageSnapshot(available: false, source: .none, observedAt: now)
    }
}
