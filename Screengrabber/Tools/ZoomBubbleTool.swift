import AppKit

class ZoomBubbleTool: DrawingTool {
    private weak var state: DrawingState?
    private var center: CGPoint?
    private var currentRadius: CGFloat = 0

    init(state: DrawingState) { self.state = state }

    func mouseDown(at point: CGPoint, in view: NSView) {
        center = point
        currentRadius = 0
    }

    func mouseDragged(to point: CGPoint, modifierFlags: NSEvent.ModifierFlags) {
        guard let c = center else { return }
        currentRadius = hypot(point.x - c.x, point.y - c.y)
    }

    func mouseUp(at point: CGPoint) {
        defer { center = nil; currentRadius = 0 }
        guard let c = center, currentRadius > 20 else { return }
        let zoom = state?.bubbleZoomLevel ?? 2.0
        state?.addAnnotation(.zoomBubble(c, currentRadius, zoom))
    }

    func drawInProgress(in context: CGContext) {
        guard let c = center, currentRadius > 0 else { return }
        let r = currentRadius
        context.saveGState()
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [5, 3])
        context.strokeEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        context.restoreGState()
    }

    func endEditing() { center = nil; currentRadius = 0 }
}
