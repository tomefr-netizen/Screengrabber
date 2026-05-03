import AppKit

class ArrowTool: DrawingTool {
    private weak var state: DrawingState?
    private var startPoint: CGPoint?
    private var endPoint: CGPoint?
    private var color: NSColor = .red
    private var width: CGFloat = 3

    init(state: DrawingState) { self.state = state }

    func mouseDown(at point: CGPoint, in view: NSView) {
        color = state?.activeColor ?? .red
        width = state?.lineWidth ?? 3
        startPoint = point
        endPoint = point
    }

    func mouseDragged(to point: CGPoint, modifierFlags: NSEvent.ModifierFlags) {
        guard let start = startPoint else { return }
        endPoint = modifierFlags.contains(.shift) ? snap45(from: start, to: point) : point
    }

    func mouseUp(at point: CGPoint, in view: NSView) {
        defer { startPoint = nil; endPoint = nil }
        guard let start = startPoint, let end = endPoint else { return }
        guard hypot(end.x - start.x, end.y - start.y) > 4 else { return }
        let annotation = Annotation.arrow(start, end, color, width)
        if let canvas = view as? CanvasView {
            state?.addAnnotation(canvas.storedAnnotation(fromViewAnnotation: annotation))
        } else {
            state?.addAnnotation(annotation)
        }
    }

    func drawInProgress(in context: CGContext) {
        guard let start = startPoint, let end = endPoint,
              hypot(end.x - start.x, end.y - start.y) > 4 else { return }
        Annotation.drawArrow(from: start, to: end, color: color, width: width, in: context)
    }

    func endEditing() { startPoint = nil; endPoint = nil }

    private func snap45(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x, dy = end.y - start.y
        let angle = (atan2(dy, dx) / (.pi / 4)).rounded() * (.pi / 4)
        let len = hypot(dx, dy)
        return CGPoint(x: start.x + cos(angle) * len, y: start.y + sin(angle) * len)
    }
}
