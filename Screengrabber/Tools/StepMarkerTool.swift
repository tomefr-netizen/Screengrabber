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
        state.addAnnotation(.stepMarker(number, point, StepMarkerTool.radius))
    }

    func mouseDragged(to point: CGPoint, modifierFlags: NSEvent.ModifierFlags) {}
    func mouseUp(at point: CGPoint) {}
    func endEditing() {}

    func drawInProgress(in context: CGContext) {}
}
