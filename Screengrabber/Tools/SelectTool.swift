import AppKit

class SelectTool: DrawingTool {
    private enum InteractionMode {
        case move
        case resize
    }

    private weak var state: DrawingState?
    private weak var canvasView: CanvasView?
    private var selectedIndex: Int? = nil
    private var dragStart: CGPoint = .zero
    private var baseAnnotation: Annotation? = nil
    private var interactionMode: InteractionMode = .move

    static let handleSize: CGFloat = 10

    init(state: DrawingState) { self.state = state }

    func mouseDown(at point: CGPoint, in view: NSView) {
        guard let canvas = view as? CanvasView else { return }
        canvasView = canvas
        let hit: Int?
        if let selectedIndex,
           let annotation = canvas.viewAnnotation(at: selectedIndex),
           let handleRect = handleRect(for: annotation),
           handleRect.insetBy(dx: -4, dy: -4).contains(point) {
            hit = selectedIndex
            interactionMode = .resize
        } else {
            hit = canvas.annotationIndex(atViewPoint: point)
            interactionMode = .move
        }
        selectedIndex = hit
        if let hit {
            baseAnnotation = canvas.viewAnnotation(at: hit)
            dragStart = point
        } else {
            baseAnnotation = nil
        }
    }

    func mouseDragged(to point: CGPoint, modifierFlags: NSEvent.ModifierFlags) {
        guard let state, let canvasView, let idx = selectedIndex, let base = baseAnnotation else { return }
        let updated: Annotation
        switch interactionMode {
        case .move:
            let offset = CGVector(dx: point.x - dragStart.x, dy: point.y - dragStart.y)
            updated = base.moved(by: offset)
        case .resize:
            updated = base.resized(byDraggingTo: point)
        }
        state.replaceAnnotation(at: idx, with: canvasView.storedAnnotation(fromViewAnnotation: updated))
    }

    func mouseUp(at point: CGPoint, in view: NSView) {
        if let idx = selectedIndex {
            baseAnnotation = canvasView?.viewAnnotation(at: idx)
            dragStart = point
        }
    }

    func drawInProgress(in context: CGContext) {
        guard let canvasView, let idx = selectedIndex, let annotation = canvasView.viewAnnotation(at: idx) else { return }
        context.saveGState()
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [5, 3])
        switch annotation {
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
        case let .symbol(_, rect, _):
            context.stroke(rect.insetBy(dx: -4, dy: -4))
        }
        if let handleRect = handleRect(for: annotation) {
            context.setLineDash(phase: 0, lengths: [])
            context.setFillColor(NSColor.systemBlue.cgColor)
            context.fillEllipse(in: handleRect)
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(1)
            context.strokeEllipse(in: handleRect)
        }
        context.restoreGState()
    }

    func endEditing() {
        selectedIndex = nil
        baseAnnotation = nil
        canvasView = nil
        interactionMode = .move
    }

    private func handleRect(for annotation: Annotation) -> CGRect? {
        guard let center = annotation.resizeHandleCenter() else { return nil }
        return CGRect(x: center.x - Self.handleSize / 2,
                      y: center.y - Self.handleSize / 2,
                      width: Self.handleSize,
                      height: Self.handleSize)
    }
}
