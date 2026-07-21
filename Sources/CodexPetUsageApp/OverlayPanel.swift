import AppKit
import CodexPetUsageCore

@MainActor
final class OverlayPanel: NSPanel {
    private let overlayView: OverlayView

    init(presentation: OverlayPresentation, layout: OverlayLayout) {
        overlayView = OverlayView(presentation: presentation, layout: layout)
        super.init(
            contentRect: layout.windowFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = overlayView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func update(presentation: OverlayPresentation, layout: OverlayLayout) {
        setFrame(layout.windowFrame, display: false)
        overlayView.update(presentation: presentation, layout: layout)
    }
}
