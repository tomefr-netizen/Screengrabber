import AppKit

class SelectTool: DrawingTool {
    private weak var state: DrawingState?
    private var selectedIndex: Int? = nil
    private var dragStart: CGPoint = .zero
    private var baseAnnotation: Annotation? = nil

    init(state: DrawingState) { self.state = state }

    func mouseDown(at point: CGPoint, in view: NSView) {
        guard let state else { return }
        let hit = state.hitTest(point)
        selectedIndex = hit
        if let hit {
            baseAnnotation = state.annotations[hit]
            dragStart = point
        } else {
            baseAnnotation = nil
        }
    }

    func mouseDragged(to point: CGPoint, modifierFlags: NSEvent.ModifierFlags) {
        guard let state, let idx = selectedIndex, let base = baseAnnotation else { return }
        let offset = CGVector(dx: point.x - dragStart.x, dy: point.y - dragStart.y)
        state.replaceAnnotation(at: idx, with: base.moved(by: offset))
    }

    func mouseUp(at point: CGPoint) {
        if let idx = selectedIndex {
            baseAnnotation = state?.annotations[idx]
            dragStart = point
        }
    }

    func drawInProgress(in context: CGContext) {
        guard let state, let idx = selectedIndex, idx < state.annotations.count else { return }
        context.saveGState()
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [5, 3])
        switch state.annotations[idx] {
        case let .text(_, _, _, rect):
            context.stroke(rect.insetBy(dx: -6, dy: -6))
        case let .path(path, _, w):
            context.stroke(path.boundingBox.insetBy(dx: -(w / 2 + 4), dy: -(w / 2 + 4)))
        case let .stepMarker(_, center, radius):
            context.stroke(CGRect(x: center.x - radius - 4, y: center.y - radius - 4,
                                  width: (radius + 4) * 2, height: (radius + 4) * 2))
        case let .arrow(start, end, _, w):
            let minX = min(start.x, end.x), minY = min(start.y, end.y)
            let maxX = max(start.x, end.x), maxY = max(start.y, end.y)
            let pad = w / 2 + 4
            context.stroke(CGRect(x: minX - pad, y: minY - pad,
                                  width: maxX - minX + pad * 2, height: maxY - minY + pad * 2))
        case let .rect(rect, _, w, _):
            context.stroke(rect.insetBy(dx: -(w / 2 + 4), dy: -(w / 2 + 4)))
        case let .ellipse(rect, _, w, _):
            context.stroke(rect.insetBy(dx: -(w / 2 + 4), dy: -(w / 2 + 4)))
        case let .blur(rect, _):
            context.stroke(rect.insetBy(dx: -4, dy: -4))
        case let .zoomBubble(center, radius, _):
            context.stroke(CGRect(x: center.x - radius - 4, y: center.y - radius - 4,
                                  width: (radius + 4) * 2, height: (radius + 4) * 2))
        }
        context.restoreGState()
    }

    func endEditing() {
        selectedIndex = nil
        baseAnnotation = nil
    }
}
