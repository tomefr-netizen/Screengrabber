import AppKit

class ShapeTool: DrawingTool {
    enum Kind { case rect, ellipse, highlight }

    private weak var state: DrawingState?
    private let kind: Kind
    private var startPoint: CGPoint?
    private var currentRect: CGRect?
    private var strokeColor: NSColor = .red
    private var strokeWidth: CGFloat = 3
    private var capturedFillColor: NSColor? = nil

    init(state: DrawingState, kind: Kind) {
        self.state = state
        self.kind = kind
    }

    func mouseDown(at point: CGPoint, in view: NSView) {
        strokeColor = state?.activeColor ?? .red
        strokeWidth = state?.lineWidth ?? 3
        startPoint = point
        currentRect = CGRect(origin: point, size: .zero)
        switch kind {
        case .highlight:
            capturedFillColor = (state?.activeColor ?? .yellow).withAlphaComponent(0.4)
            strokeWidth = 0
        case .rect, .ellipse:
            capturedFillColor = (state?.fillEnabled ?? false) ? state?.fillColor : nil
        }
    }

    func mouseDragged(to point: CGPoint, modifierFlags: NSEvent.ModifierFlags) {
        guard let start = startPoint else { return }
        var dx = point.x - start.x, dy = point.y - start.y
        if modifierFlags.contains(.shift) {
            let s = max(abs(dx), abs(dy))
            dx = dx >= 0 ? s : -s
            dy = dy >= 0 ? s : -s
        }
        currentRect = CGRect(x: min(start.x, start.x + dx), y: min(start.y, start.y + dy),
                             width: abs(dx), height: abs(dy))
    }

    func mouseUp(at point: CGPoint) {
        defer { startPoint = nil; currentRect = nil; capturedFillColor = nil }
        guard let rect = currentRect, rect.width > 4, rect.height > 4 else { return }
        switch kind {
        case .rect, .highlight:
            state?.addAnnotation(.rect(rect, strokeColor, strokeWidth, capturedFillColor))
        case .ellipse:
            state?.addAnnotation(.ellipse(rect, strokeColor, strokeWidth, capturedFillColor))
        }
    }

    func drawInProgress(in context: CGContext) {
        guard let rect = currentRect, rect.width > 0, rect.height > 0 else { return }
        context.saveGState()
        if let fill = capturedFillColor {
            context.setFillColor(fill.cgColor)
            switch kind {
            case .rect, .highlight: context.fill(rect)
            case .ellipse:          context.fillEllipse(in: rect)
            }
        }
        if strokeWidth > 0 {
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineWidth(strokeWidth)
            switch kind {
            case .rect, .highlight: context.stroke(rect)
            case .ellipse:          context.strokeEllipse(in: rect)
            }
        }
        context.restoreGState()
    }

    func endEditing() { startPoint = nil; currentRect = nil; capturedFillColor = nil }
}
