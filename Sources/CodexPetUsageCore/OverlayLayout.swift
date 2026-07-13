import CoreGraphics

public struct OverlayLayout: Sendable {
    public let ringSize: CGFloat
    public let windowFrame: CGRect
    public let ringCenter: CGPoint
    public let outerRadius: CGFloat
    public let innerRadius: CGFloat
    public let cardFrame: CGRect
    public let placesCardOnLeft: Bool

    public static func compute(pet: PetGeometry, primaryMaxY: CGFloat) -> OverlayLayout {
        let cardSize = CGSize(width: 222, height: 88)
        let gap: CGFloat = 10
        let ringSize = max(104, max(pet.topLeftRect.width, pet.topLeftRect.height) + 52)
        let windowHeight = max(ringSize, 96)
        let windowWidth = ringSize + gap + cardSize.width
        let ringLeft = pet.topLeftRect.midX - ringSize / 2
        let ringTop = pet.topLeftRect.midY - ringSize / 2
        let displayRight = pet.displayTopLeftRect.maxX
        let placesCardOnLeft = ringLeft + ringSize + gap + cardSize.width > displayRight

        let windowLeft = placesCardOnLeft ? ringLeft - gap - cardSize.width : ringLeft
        let ringX = placesCardOnLeft ? cardSize.width + gap : 0
        let cardX = placesCardOnLeft ? 0 : ringSize + gap
        let cardY = max(0, (windowHeight - cardSize.height) / 2)

        return OverlayLayout(
            ringSize: ringSize,
            windowFrame: CGRect(
                x: windowLeft,
                y: primaryMaxY - ringTop - windowHeight,
                width: windowWidth,
                height: windowHeight
            ),
            ringCenter: CGPoint(x: ringX + ringSize / 2, y: windowHeight / 2),
            outerRadius: ringSize / 2 - 7,
            innerRadius: ringSize / 2 - 20,
            cardFrame: CGRect(origin: CGPoint(x: cardX, y: cardY), size: cardSize),
            placesCardOnLeft: placesCardOnLeft
        )
    }
}
