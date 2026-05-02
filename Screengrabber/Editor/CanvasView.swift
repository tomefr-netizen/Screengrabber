import AppKit
import CoreImage
import Observation

class CanvasView: NSView {
    private(set) var state: DrawingState?
    private var penTool: PenTool?
    private var textTool: TextTool?
    private var selectTool: SelectTool?
    private var stepMarkerTool: StepMarkerTool?
    private var arrowTool: ArrowTool?
    private var rectTool: ShapeTool?
    private var ellipseTool: ShapeTool?
    private var highlightTool: ShapeTool?
    private var blurTool: BlurTool?
    private var highlighterTool: HighlighterTool?
    private var magnifierTool: ZoomBubbleTool?

    private let ciContext = CIContext()

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    func setup(state: DrawingState) {
        self.state = state
        penTool = PenTool(state: state)
        textTool = TextTool(state: state)
        selectTool = SelectTool(state: state)
        stepMarkerTool = StepMarkerTool(state: state)
        arrowTool = ArrowTool(state: state)
        rectTool = ShapeTool(state: state, kind: .rect)
        ellipseTool = ShapeTool(state: state, kind: .ellipse)
        highlightTool = ShapeTool(state: state, kind: .highlight)
        blurTool = BlurTool(state: state)
        highlighterTool = HighlighterTool(state: state)
        magnifierTool = ZoomBubbleTool(state: state)
        observeState()
    }

    private func observeState() {
        withObservationTracking {
            _ = state?.annotations
            _ = state?.activeTool
            _ = state?.baseImage
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.needsDisplay = true
                self?.observeState()
            }
        }
    }

    private func activeTool() -> (any DrawingTool)? {
        switch state?.activeTool {
        case .select:        return selectTool
        case .pen:           return penTool
        case .highlighterPen: return highlighterTool
        case .text:          return textTool
        case .stepMarker:    return stepMarkerTool
        case .arrow:         return arrowTool
        case .rect:          return rectTool
        case .ellipse:       return ellipseTool
        case .highlight:     return highlightTool
        case .blur:          return blurTool
        case .magnifier:     return magnifierTool
        case nil:            return nil
        }
    }

    func finalizeActiveTool() {
        activeTool()?.endEditing()
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        activeTool()?.mouseDown(at: p, in: self)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        activeTool()?.mouseDragged(to: p, modifierFlags: event.modifierFlags)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        activeTool()?.mouseUp(at: p)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) else { super.keyDown(with: event); return }
        if event.keyCode == 6 { // Z
            event.modifierFlags.contains(.shift) ? state?.redo() : state?.undo()
            needsDisplay = true
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext, let state else { return }

        if let image = state.baseImage {
            ctx.saveGState()
            ctx.translateBy(x: 0, y: bounds.height)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(image, in: bounds)
            ctx.restoreGState()
        } else {
            NSColor.windowBackgroundColor.setFill()
            bounds.fill()
        }

        state.annotations.forEach { drawAnnotation($0, in: ctx) }
        activeTool()?.drawInProgress(in: ctx)
    }

    func drawAnnotation(_ annotation: Annotation, in ctx: CGContext) {
        switch annotation {
        case let .path(path, color, width):
            ctx.saveGState()
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(width)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.addPath(path)
            ctx.strokePath()
            ctx.restoreGState()

        case let .text(string, font, color, rect):
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            (string as NSString).draw(in: rect, withAttributes: attrs)

        case let .stepMarker(number, center, radius):
            ctx.saveGState()
            ctx.setFillColor(NSColor.systemRed.cgColor)
            ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                       width: radius * 2, height: radius * 2))
            let fontSize = radius * 1.1
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: NSColor.white
            ]
            let str = "\(number)" as NSString
            let sz = str.size(withAttributes: attrs)
            str.draw(at: CGPoint(x: center.x - sz.width / 2, y: center.y - sz.height / 2),
                     withAttributes: attrs)
            ctx.restoreGState()

        case let .arrow(start, end, color, width):
            Annotation.drawArrow(from: start, to: end, color: color, width: width, in: ctx)

        case let .rect(rect, color, width, fill):
            ctx.saveGState()
            if let fill {
                ctx.setFillColor(fill.cgColor)
                ctx.fill(rect)
            }
            if width > 0 {
                ctx.setStrokeColor(color.cgColor)
                ctx.setLineWidth(width)
                ctx.stroke(rect)
            }
            ctx.restoreGState()

        case let .ellipse(rect, color, width, fill):
            ctx.saveGState()
            if let fill {
                ctx.setFillColor(fill.cgColor)
                ctx.fillEllipse(in: rect)
            }
            if width > 0 {
                ctx.setStrokeColor(color.cgColor)
                ctx.setLineWidth(width)
                ctx.strokeEllipse(in: rect)
            }
            ctx.restoreGState()

        case let .blur(rect, kind):
            if let baseImage = state?.baseImage {
                drawBlur(rect: rect, kind: kind, baseImage: baseImage, in: ctx)
            }

        case let .zoomBubble(center, radius, zoomLevel):
            if let baseImage = state?.baseImage {
                drawZoomBubble(center: center, radius: radius, zoomLevel: zoomLevel,
                               baseImage: baseImage, in: ctx)
            }
        }
    }

    private func drawBlur(rect: CGRect, kind: BlurKind, baseImage: CGImage, in ctx: CGContext) {
        let imgW = CGFloat(baseImage.width), imgH = CGFloat(baseImage.height)
        let scaleX = imgW / bounds.width, scaleY = imgH / bounds.height
        // Convert view rect (y-down) to image rect (y-up)
        let imageRect = CGRect(x: rect.minX * scaleX,
                               y: (bounds.height - rect.maxY) * scaleY,
                               width: rect.width * scaleX,
                               height: rect.height * scaleY)
        guard let cropped = baseImage.cropping(to: imageRect) else { return }
        guard let result = applyBlurFilter(to: cropped, kind: kind) else { return }

        // Draw in view space: un-flip context before drawing CGImage
        ctx.saveGState()
        ctx.clip(to: rect)
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(result, in: CGRect(origin: .zero, size: rect.size))
        ctx.restoreGState()
    }

    private func drawZoomBubble(center: CGPoint, radius: CGFloat, zoomLevel: CGFloat,
                                baseImage: CGImage, in ctx: CGContext) {
        let bubbleRect = CGRect(x: center.x - radius, y: center.y - radius,
                                width: radius * 2, height: radius * 2)
        let circlePath = CGPath(ellipseIn: bubbleRect, transform: nil)

        ctx.saveGState()
        ctx.addPath(circlePath)
        ctx.clip()

        // Zoom in around center using the same draw approach as draw()
        // This is guaranteed correct regardless of image scale
        ctx.translateBy(x: center.x, y: center.y)
        ctx.scaleBy(x: zoomLevel, y: zoomLevel)
        ctx.translateBy(x: -center.x, y: -center.y)
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(baseImage, in: CGRect(origin: .zero, size: bounds.size))

        ctx.restoreGState()

        // Border
        ctx.saveGState()
        ctx.addPath(circlePath)
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(3)
        ctx.strokePath()
        ctx.addPath(circlePath)
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.35).cgColor)
        ctx.setLineWidth(1)
        ctx.strokePath()
        ctx.restoreGState()
    }

    private func applyBlurFilter(to image: CGImage, kind: BlurKind) -> CGImage? {
        let ciInput = CIImage(cgImage: image)
        let filter: CIFilter?
        switch kind {
        case let .gaussian(radius):
            let f = CIFilter(name: "CIGaussianBlur")
            f?.setValue(ciInput, forKey: kCIInputImageKey)
            f?.setValue(radius, forKey: kCIInputRadiusKey)
            filter = f
        case let .pixelate(scale):
            let f = CIFilter(name: "CIPixellate")
            f?.setValue(ciInput, forKey: kCIInputImageKey)
            f?.setValue(scale, forKey: kCIInputScaleKey)
            f?.setValue(CIVector(x: ciInput.extent.midX, y: ciInput.extent.midY),
                        forKey: kCIInputCenterKey)
            filter = f
        }
        guard let output = filter?.outputImage else { return nil }
        return ciContext.createCGImage(output, from: ciInput.extent)
    }
}
