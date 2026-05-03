import AppKit

class RegionSelectorView: NSView {
    var onSelection: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    private let screenImage: CGImage
    private var startPoint: NSPoint = .zero
    private var selectionRect: NSRect = .zero
    private var isDragging = false

    init(frame: NSRect, screenImage: CGImage) {
        self.screenImage = screenImage
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Draw frozen screen (flip for CGContext in flipped NSView)
        ctx.saveGState()
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(screenImage, in: bounds)
        ctx.restoreGState()

        // Dim overlay
        NSColor.black.withAlphaComponent(0.4).setFill()
        bounds.fill()

        if isDragging && selectionRect.width > 0 && selectionRect.height > 0 {
            // Clear the selected region
            ctx.saveGState()
            ctx.setBlendMode(.clear)
            ctx.fill(selectionRect)
            ctx.restoreGState()

            // Redraw the screenshot in the clear region
            ctx.saveGState()
            ctx.clip(to: selectionRect)
            ctx.translateBy(x: 0, y: bounds.height)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(screenImage, in: bounds)
            ctx.restoreGState()

            // Selection border
            NSColor.white.withAlphaComponent(0.9).setStroke()
            let border = NSBezierPath(rect: selectionRect.insetBy(dx: 0.5, dy: 0.5))
            border.lineWidth = 1.5
            border.stroke()

            // Size hint
            let label = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.white
            ]
            let labelSize = (label as NSString).size(withAttributes: attrs)
            var labelOrigin = NSPoint(x: selectionRect.minX + 4, y: selectionRect.minY + 4)
            if labelOrigin.y + labelSize.height > selectionRect.maxY { labelOrigin.y = selectionRect.maxY - labelSize.height - 4 }
            (label as NSString).draw(at: labelOrigin, withAttributes: attrs)
        }

        // Instruction label (only when not dragging)
        if !isDragging {
            let hint = "Klicka och dra för att välja område  ·  Esc = avbryt"
            let hintAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: NSColor.white
            ]
            let hintSize = (hint as NSString).size(withAttributes: hintAttrs)
            let hintOrigin = NSPoint(x: (bounds.width - hintSize.width) / 2, y: bounds.height * 0.85)
            let hintBackground = NSRect(x: hintOrigin.x - 10, y: hintOrigin.y - 6,
                                        width: hintSize.width + 20, height: hintSize.height + 12)
            NSColor.black.withAlphaComponent(0.6).setFill()
            NSBezierPath(roundedRect: hintBackground, xRadius: 6, yRadius: 6).fill()
            (hint as NSString).draw(at: hintOrigin, withAttributes: hintAttrs)
        }

        // Crosshair cursor hint at edges
        NSColor.white.withAlphaComponent(0.6).setStroke()
        let cursorHint = NSBezierPath()
        let cx = !isDragging ? bounds.midX : selectionRect.maxX
        let cy = !isDragging ? bounds.midY : selectionRect.maxY
        cursorHint.move(to: NSPoint(x: cx - 8, y: cy))
        cursorHint.line(to: NSPoint(x: cx + 8, y: cy))
        cursorHint.move(to: NSPoint(x: cx, y: cy - 8))
        cursorHint.line(to: NSPoint(x: cx, y: cy + 8))
        cursorHint.lineWidth = 1
        cursorHint.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        selectionRect = NSRect(origin: startPoint, size: .zero)
        isDragging = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let current = convert(event.locationInWindow, from: nil)
        selectionRect = NSRect(
            x: min(startPoint.x, current.x),
            y: min(startPoint.y, current.y),
            width: abs(current.x - startPoint.x),
            height: abs(current.y - startPoint.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        if selectionRect.width > 10 && selectionRect.height > 10 {
            onSelection?(selectionRect)
        } else {
            cancelCapture()
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            cancelCapture()
        } else {
            super.keyDown(with: event)
        }
    }

    private func cancelCapture() {
        onCancel?()
    }
}
