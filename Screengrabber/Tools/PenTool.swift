import AppKit

class PenTool: DrawingTool {
    private var points: [CGPoint] = []
    private var color: NSColor = .red
    private var width: CGFloat = 3
    private weak var state: DrawingState?

    init(state: DrawingState) {
        self.state = state
    }

    func mouseDown(at point: CGPoint, in view: NSView) {
        color = state?.activeColor ?? .red
        width = state?.lineWidth ?? 3
        points = [point]
    }

    func mouseDragged(to point: CGPoint, modifierFlags: NSEvent.ModifierFlags) {
        guard let start = points.first else { return }
        if modifierFlags.contains(.shift) {
            points = [start, snap45(from: start, to: point)]
        } else {
            points.append(point)
        }
    }

    func mouseUp(at point: CGPoint, in view: NSView) {
        defer { points.removeAll() }
        guard points.count >= 2 else { return }
        let path = CGMutablePath()
        path.move(to: points[0])
        points.dropFirst().forEach { path.addLine(to: $0) }
        let annotation = Annotation.path(path, color, width)
        if let canvas = view as? CanvasView {
            state?.addAnnotation(canvas.storedAnnotation(fromViewAnnotation: annotation))
        } else {
            state?.addAnnotation(annotation)
        }
    }

    func drawInProgress(in context: CGContext) {
        guard points.count >= 2 else { return }
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.beginPath()
        context.move(to: points[0])
        points.dropFirst().forEach { context.addLine(to: $0) }
        context.strokePath()
        context.restoreGState()
    }

    func endEditing() { points.removeAll() }

    private func snap45(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x, dy = end.y - start.y
        let angle = (atan2(dy, dx) / (.pi / 4)).rounded() * (.pi / 4)
        let len = (dx * dx + dy * dy).squareRoot()
        return CGPoint(x: start.x + cos(angle) * len, y: start.y + sin(angle) * len)
    }
}
