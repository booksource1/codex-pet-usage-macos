import Foundation
import CoreGraphics

public struct PetGeometry: Sendable {
    public let topLeftRect: CGRect
    public let appKitRect: CGRect
    public let displayTopLeftRect: CGRect
    public let overlayTopLeftRect: CGRect?

    public init(
        topLeftRect: CGRect,
        appKitRect: CGRect,
        displayTopLeftRect: CGRect,
        overlayTopLeftRect: CGRect? = nil
    ) {
        self.topLeftRect = topLeftRect
        self.appKitRect = appKitRect
        self.displayTopLeftRect = displayTopLeftRect
        self.overlayTopLeftRect = overlayTopLeftRect
    }

    public func corrected(liveOverlayFrame: CGRect?, primaryMaxY: CGFloat) -> PetGeometry {
        guard let jsonFrame = overlayTopLeftRect, let liveOverlayFrame else { return self }

        let correctedTopLeft = topLeftRect.offsetBy(
            dx: liveOverlayFrame.minX - jsonFrame.minX,
            dy: liveOverlayFrame.minY - jsonFrame.minY
        )
        return PetGeometry(
            topLeftRect: correctedTopLeft,
            appKitRect: CGRect(
                x: correctedTopLeft.minX,
                y: primaryMaxY - correctedTopLeft.minY - correctedTopLeft.height,
                width: correctedTopLeft.width,
                height: correctedTopLeft.height
            ),
            displayTopLeftRect: displayTopLeftRect,
            overlayTopLeftRect: liveOverlayFrame
        )
    }
}

public enum CodexStateReader {
    public static func read(codexHome: URL, primaryMaxY: CGFloat) -> PetGeometry? {
        let stateURL = codexHome.appendingPathComponent(".codex-global-state.json")
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return decode(data: data, primaryMaxY: primaryMaxY)
    }

    public static func decode(data: Data, primaryMaxY: CGFloat) -> PetGeometry? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let root = object as? [String: Any],
            root["electron-avatar-overlay-open"] as? Bool == true,
            let rawBounds = root["electron-avatar-overlay-bounds"] as? [String: Any],
            let bounds = boundsWithMascot(from: rawBounds),
            let mascot = bounds["mascot"] as? [String: Any],
            let mascotLeft = number(mascot["left"]),
            let mascotTop = number(mascot["top"]),
            let mascotWidth = number(mascot["width"]),
            let mascotHeight = number(mascot["height"])
        else {
            return nil
        }

        let left = number(bounds["x"]) ?? 0
        let top = number(bounds["y"]) ?? 0
        let topLeftRect = CGRect(
            x: left + mascotLeft,
            y: top + mascotTop,
            width: mascotWidth,
            height: mascotHeight
        )
        let appKitRect = CGRect(
            x: topLeftRect.minX,
            y: primaryMaxY - topLeftRect.minY - topLeftRect.height,
            width: topLeftRect.width,
            height: topLeftRect.height
        )

        let display = bounds["displayBounds"] as? [String: Any]
        let displayRect = CGRect(
            x: number(display?["x"]) ?? 0,
            y: number(display?["y"]) ?? 0,
            width: number(display?["width"]) ?? 1920,
            height: number(display?["height"]) ?? 1080
        )
        let overlayRect: CGRect? = if let width = number(bounds["width"]), let height = number(bounds["height"]) {
            CGRect(x: left, y: top, width: width, height: height)
        } else {
            nil
        }
        return PetGeometry(
            topLeftRect: topLeftRect,
            appKitRect: appKitRect,
            displayTopLeftRect: displayRect,
            overlayTopLeftRect: overlayRect
        )
    }

    private static func boundsWithMascot(from bounds: [String: Any]) -> [String: Any]? {
        if bounds["mascot"] is [String: Any] {
            return bounds
        }

        guard let byDisplayID = bounds["byDisplayId"] as? [String: Any] else {
            return nil
        }

        let origin = CGPoint(
            x: number(bounds["x"]) ?? 0,
            y: number(bounds["y"]) ?? 0
        )
        return byDisplayID.keys.sorted().compactMap { key in
            guard
                let candidate = byDisplayID[key] as? [String: Any],
                candidate["mascot"] is [String: Any],
                number(candidate["x"]) != nil,
                number(candidate["y"]) != nil
            else {
                return nil
            }
            return candidate
        }.min { lhs, rhs in
            distanceSquared(from: lhs, to: origin) < distanceSquared(from: rhs, to: origin)
        }
    }

    private static func distanceSquared(from bounds: [String: Any], to point: CGPoint) -> CGFloat {
        let dx = (number(bounds["x"]) ?? 0) - point.x
        let dy = (number(bounds["y"]) ?? 0) - point.y
        return dx * dx + dy * dy
    }

    private static func number(_ value: Any?) -> CGFloat? {
        if let value = value as? NSNumber {
            return CGFloat(value.doubleValue)
        }
        if let value = value as? String, let double = Double(value) {
            return CGFloat(double)
        }
        return nil
    }
}
