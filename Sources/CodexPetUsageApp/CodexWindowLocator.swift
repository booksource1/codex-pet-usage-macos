import AppKit
import CodexPetUsageCore
import CoreGraphics

@MainActor
enum CodexWindowLocator {
    static func closestFrame(expected: CGRect) -> CGRect? {
        guard
            expected.origin.x.isFinite,
            expected.origin.y.isFinite,
            expected.width.isFinite,
            expected.height.isFinite,
            expected.width > 0,
            expected.height > 0
        else {
            return nil
        }

        let codexPIDs = Set(
            NSWorkspace.shared.runningApplications.compactMap { application in
                application.bundleIdentifier == "com.openai.codex"
                    ? application.processIdentifier
                    : nil
            }
        )
        guard !codexPIDs.isEmpty else { return nil }

        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        let candidates = windowInfo.compactMap { entry -> CGRect? in
            guard
                let ownerPID = entry[kCGWindowOwnerPID as String] as? NSNumber,
                codexPIDs.contains(ownerPID.int32Value),
                let bounds = entry[kCGWindowBounds as String] as? NSDictionary,
                let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                frame.origin.x.isFinite,
                frame.origin.y.isFinite,
                frame.width.isFinite,
                frame.height.isFinite,
                frame.width > 0,
                frame.height > 0
            else {
                return nil
            }
            return frame
        }

        return closestMatchingWindowFrame(expected: expected, candidates: candidates)
    }
}
