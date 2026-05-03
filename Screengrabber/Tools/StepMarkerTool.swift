import AppKit

class StepMarkerTool: DrawingTool {
    private weak var state: DrawingState?
    static let radius: CGFloat = 16

    init(state: DrawingState) { self.state = state }

    func mouseDown(at point: CGPoint, in view: NSView) {
        guard let state else { return }
        let existing = state.annotations.filter {
            if case .stepMarker = $0 { return true }
            return false
        }.count
        let number = (existing % 20) + 1
        let annotation = Annotation.stepMarker(number, point, StepMarkerTool.radius)
        if let canvas = view as? CanvasView {
            state.addAnnotation(canvas.storedAnnotation(fromViewAnnotation: annotation))
        } else {
            state.addAnnotation(annotation)
        }
    }

    func mouseDragged(to point: CGPoint, modifierFlags: NSEvent.ModifierFlags) {}
    func mouseUp(at point: CGPoint, in view: NSView) {}
    func endEditing() {}

    func drawInProgress(in context: CGContext) {}
}

class SymbolTool: DrawingTool {
    private weak var state: DrawingState?
    static let defaultSize = CGSize(width: 30, height: 30)

    init(state: DrawingState) { self.state = state }

    func mouseDown(at point: CGPoint, in view: NSView) {
        guard let state else { return }
        let rect = CGRect(origin: point, size: Self.defaultSize).offsetBy(dx: -Self.defaultSize.width / 2,
                                                                           dy: -Self.defaultSize.height / 2)
        let annotation = Annotation.symbol(state.selectedSymbol, rect, state.activeColor)
        if let canvas = view as? CanvasView {
            state.addAnnotation(canvas.storedAnnotation(fromViewAnnotation: annotation))
        } else {
            state.addAnnotation(annotation)
        }
    }

    func mouseDragged(to point: CGPoint, modifierFlags: NSEvent.ModifierFlags) {}
    func mouseUp(at point: CGPoint, in view: NSView) {}
    func endEditing() {}
    func drawInProgress(in context: CGContext) {}
}
