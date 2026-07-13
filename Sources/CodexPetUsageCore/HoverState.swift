import CoreGraphics
import Foundation

public func pointIsInside(_ point: CGPoint, rect: CGRect, padding: CGFloat = 0) -> Bool {
    let paddedRect = rect.insetBy(dx: -padding, dy: -padding)
    return point.x >= paddedRect.minX
        && point.x <= paddedRect.maxX
        && point.y >= paddedRect.minY
        && point.y <= paddedRect.maxY
}

public struct HoverState: Sendable {
    public private(set) var showUntil: Date?
    public private(set) var cursorWasInPet = false
    public private(set) var overlayWasVisible = false

    public init() {}

    public mutating func update(
        pet: PetGeometry?,
        cursor: CGPoint,
        now: Date,
        padding: CGFloat = 24,
        showSeconds: TimeInterval = 10
    ) -> Bool {
        guard let pet else {
            showUntil = nil
            cursorWasInPet = false
            return false
        }

        let cursorIsInPet = pointIsInside(cursor, rect: pet.appKitRect, padding: padding)
        if cursorIsInPet, !cursorWasInPet, showUntil.map({ now > $0 }) ?? true {
            showUntil = now.addingTimeInterval(showSeconds)
        }

        cursorWasInPet = cursorIsInPet
        overlayWasVisible = showUntil.map { now <= $0 } ?? false
        return overlayWasVisible
    }
}
