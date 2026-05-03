import AppKit

class BlurTool: DrawingTool {
    private weak var state: DrawingState?
    private var startPoint: CGPoint?
    private var currentRect: CGRect?

    init(state: DrawingState) { self.state = state }

    func mouseDown(at point: CGPoint, in view: NSView) {
        startPoint = point
        currentRect = CGRect(origin: point, size: .zero)
    }

    func mouseDragged(to point: CGPoint, modifierFlags: NSEvent.ModifierFlags) {
        guard let start = startPoint else { return }
        currentRect = CGRect(x: min(start.x, point.x), y: min(start.y, point.y),
                             width: abs(point.x - start.x), height: abs(point.y - start.y))
    }

    func mouseUp(at point: CGPoint, in view: NSView) {
        defer { startPoint = nil; currentRect = nil }
        guard let rect = currentRect, rect.width > 8, rect.height > 8 else { return }
        let kind: BlurKind = state?.blurMode == .pixelate
            ? .pixelate(scale: 16)
            : .gaussian(radius: 20)
        let annotation = Annotation.blur(rect, kind)
        if let canvas = view as? CanvasView {
            state?.addAnnotation(canvas.storedAnnotation(fromViewAnnotation: annotation))
        } else {
            state?.addAnnotation(annotation)
        }
    }

    func drawInProgress(in context: CGContext) {
        guard let rect = currentRect, rect.width > 0, rect.height > 0 else { return }
        context.saveGState()
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [4, 3])
        context.stroke(rect)
        context.restoreGState()
    }

    func endEditing() { startPoint = nil; currentRect = nil }
}
