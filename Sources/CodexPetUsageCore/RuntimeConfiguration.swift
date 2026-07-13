import Foundation

public struct RuntimeConfiguration: Sendable, Equatable {
    public let codexHome: URL
    public let usagePollSeconds: TimeInterval
    public let petPollMilliseconds: Int
    public let hoverPadding: CGFloat

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        if let path = environment["CODEX_HOME"], !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            codexHome = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        } else {
            codexHome = homeDirectory.appendingPathComponent(".codex", isDirectory: true)
        }

        usagePollSeconds = max(
            10,
            Self.double(environment["CODEX_PET_USAGE_POLL_SECONDS"]) ?? OverlayDefaults.usagePollSeconds
        )
        petPollMilliseconds = max(
            50,
            Self.integer(environment["CODEX_PET_POLL_MS"]) ?? OverlayDefaults.petPollMilliseconds
        )
        hoverPadding = min(
            200,
            max(0, Self.double(environment["CODEX_PET_HOVER_PADDING"]) ?? Double(OverlayDefaults.hoverPadding))
        )
    }

    private static func double(_ value: String?) -> Double? {
        guard let value, let number = Double(value), number.isFinite else { return nil }
        return number
    }

    private static func integer(_ value: String?) -> Int? {
        guard let value, let number = Int(value) else { return nil }
        return number
    }
}

public struct SafeLogMessage: Sendable, Equatable {
    public let text: String

    fileprivate init(text: String) {
        self.text = text
    }
}

public enum LogMessagePolicy {
    private static let forbiddenFragments = [
        "authorization",
        "bearer",
        "token",
        "response body",
        "response_body",
        "feedback_log_body",
        "codex.rate_limits",
    ]

    public static func validate(_ candidate: String) -> SafeLogMessage? {
        let lowered = candidate.lowercased()
        guard
            !candidate.isEmpty,
            !candidate.contains("\n"),
            !candidate.contains("\r"),
            !forbiddenFragments.contains(where: lowered.contains)
        else {
            return nil
        }
        return SafeLogMessage(text: candidate)
    }
}
