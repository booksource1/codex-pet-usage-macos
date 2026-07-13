import AppKit
import CodexPetUsageCore

@MainActor
final class OverlayView: NSView {
    private var presentation: OverlayPresentation
    private var layout: OverlayLayout

    init(presentation: OverlayPresentation, layout: OverlayLayout) {
        self.presentation = presentation
        self.layout = layout
        super.init(frame: CGRect(origin: .zero, size: layout.windowFrame.size))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool { true }

    func update(presentation: OverlayPresentation, layout: OverlayLayout) {
        self.presentation = presentation
        self.layout = layout
        frame = CGRect(origin: .zero, size: layout.windowFrame.size)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        drawTrack(radius: layout.outerRadius, width: 7, alpha: 35.0 / 255.0)
        drawTrack(radius: layout.innerRadius, width: 5, alpha: 28.0 / 255.0)
        drawArc(
            percent: presentation.primaryPercent,
            radius: layout.outerRadius,
            width: 7,
            color: NSColor(
                calibratedRed: 0x3C / 255.0,
                green: 0xEB / 255.0,
                blue: 0xBD / 255.0,
                alpha: 215.0 / 255.0
            )
        )
        drawArc(
            percent: presentation.secondaryPercent,
            radius: layout.innerRadius,
            width: 5,
            color: NSColor(
                calibratedRed: 0x56 / 255.0,
                green: 0xB2 / 255.0,
                blue: 1,
                alpha: 205.0 / 255.0
            )
        )
        drawCard()
    }

    private func drawTrack(radius: CGFloat, width: CGFloat, alpha: CGFloat) {
        let rect = CGRect(
            x: layout.ringCenter.x - radius,
            y: layout.ringCenter.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        let path = NSBezierPath(ovalIn: rect)
        path.lineWidth = width
        NSColor.white.withAlphaComponent(alpha).setStroke()
        path.stroke()
    }

    private func drawArc(percent: Double, radius: CGFloat, width: CGFloat, color: NSColor) {
        guard percent > 0 else { return }
        let visiblePercent = min(99.99, max(0.01, percent))
        let path = NSBezierPath()
        path.lineWidth = width
        path.lineCapStyle = .round
        path.appendArc(
            withCenter: layout.ringCenter,
            radius: radius,
            startAngle: -90,
            endAngle: -90 + 360 * visiblePercent / 100,
            clockwise: false
        )
        color.setStroke()
        path.stroke()
    }

    private func drawCard() {
        let card = NSBezierPath(roundedRect: layout.cardFrame, xRadius: 6, yRadius: 6)
        NSColor(
            calibratedRed: 0x0D / 255.0,
            green: 0x18 / 255.0,
            blue: 0x1E / 255.0,
            alpha: 205.0 / 255.0
        ).setFill()
        card.fill()

        let x = layout.cardFrame.minX + 10
        let y = layout.cardFrame.minY + 8
        drawText(
            presentation.title,
            at: CGPoint(x: x, y: y),
            font: .systemFont(ofSize: 12, weight: .semibold),
            color: .white.withAlphaComponent(230.0 / 255.0)
        )
        drawText(
            presentation.primary,
            at: CGPoint(x: x, y: y + 18),
            font: .systemFont(ofSize: 12),
            color: .white.withAlphaComponent(238.0 / 255.0)
        )
        drawText(
            presentation.secondary,
            at: CGPoint(x: x, y: y + 36),
            font: .systemFont(ofSize: 12),
            color: .white.withAlphaComponent(238.0 / 255.0)
        )
        drawText(
            presentation.status,
            at: CGPoint(x: x, y: y + 54),
            font: .systemFont(ofSize: 10),
            color: NSColor(
                calibratedRed: 0xB8 / 255.0,
                green: 0xC5 / 255.0,
                blue: 0xCC / 255.0,
                alpha: 215.0 / 255.0
            )
        )
    }

    private func drawText(_ text: String, at point: CGPoint, font: NSFont, color: NSColor) {
        NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: color]
        ).draw(at: point)
    }
}
