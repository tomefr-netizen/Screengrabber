import AppKit

class TextTool: NSObject, DrawingTool, NSTextFieldDelegate {
    private weak var state: DrawingState?
    private weak var textField: NSTextField?

    init(state: DrawingState) {
        self.state = state
    }

    func mouseDown(at point: CGPoint, in view: NSView) {
        commitIfNeeded()
        let f = NSTextField(frame: NSRect(x: point.x, y: point.y - 24, width: 220, height: 32))
        f.isBezeled = true
        f.bezelStyle = .roundedBezel
        f.isEditable = true
        f.drawsBackground = true
        f.backgroundColor = NSColor.white.withAlphaComponent(0.88)
        f.textColor = state?.activeColor ?? .red
        f.font = NSFont.systemFont(ofSize: 18, weight: .regular)
        f.placeholderString = "Text…"
        f.delegate = self
        view.addSubview(f)
        view.window?.makeFirstResponder(f)
        textField = f
    }

    func mouseDragged(to point: CGPoint, modifierFlags: NSEvent.ModifierFlags) {}
    func mouseUp(at point: CGPoint) {}
    func drawInProgress(in context: CGContext) {}
    func endEditing() { commitIfNeeded() }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) { commit(); return true }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) { cancel(); return true }
        return false
    }

    private func commit() {
        guard let f = textField else { return }
        let text = f.stringValue
        if !text.isEmpty {
            let font = f.font ?? NSFont.systemFont(ofSize: 18)
            let color = f.textColor ?? (state?.activeColor ?? .red)
            state?.addAnnotation(.text(text, font, color, f.frame))
        }
        f.removeFromSuperview()
        f.superview?.needsDisplay = true
        textField = nil
    }

    private func cancel() {
        textField?.removeFromSuperview()
        textField = nil
    }

    private func commitIfNeeded() {
        guard textField != nil else { return }
        commit()
    }
}
