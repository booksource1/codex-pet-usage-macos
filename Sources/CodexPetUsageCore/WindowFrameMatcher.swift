import CoreGraphics

public func closestMatchingWindowFrame(
    expected: CGRect,
    candidates: [CGRect],
    sizeTolerance: CGFloat = 1
) -> CGRect? {
    var best: (frame: CGRect, distance: CGFloat)?

    for frame in candidates {
        guard
            abs(frame.width - expected.width) <= sizeTolerance,
            abs(frame.height - expected.height) <= sizeTolerance
        else {
            continue
        }

        let dx = frame.minX - expected.minX
        let dy = frame.minY - expected.minY
        let distance = dx * dx + dy * dy
        if best == nil || distance < best!.distance {
            best = (frame, distance)
        }
    }

    return best?.frame
}
