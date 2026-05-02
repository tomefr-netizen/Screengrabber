import AppKit

protocol DrawingTool: AnyObject {
    func mouseDown(at point: CGPoint, in view: NSView)
    func mouseDragged(to point: CGPoint, modifierFlags: NSEvent.ModifierFlags)
    func mouseUp(at point: CGPoint)
    func drawInProgress(in context: CGContext)
    func endEditing()
}
