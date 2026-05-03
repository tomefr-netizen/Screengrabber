import AppKit
import CoreImage
import Observation

class CanvasView: NSView {
    struct CanvasTransform {
        let imageSize: CGSize
        let bounds: CGRect

        var scale: CGFloat {
            guard imageSize.width > 0, imageSize.height > 0,
                  bounds.width > 0, bounds.height > 0 else { return 1 }
            return min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        }

        var imageRect: CGRect {
            let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            return CGRect(
                x: bounds.midX - fittedSize.width / 2,
                y: bounds.midY - fittedSize.height / 2,
                width: fittedSize.width,
                height: fittedSize.height
            )
        }

        func viewPoint(fromImagePoint point: CGPoint) -> CGPoint {
            CGPoint(
                x: imageRect.minX + point.x * scale,
                y: imageRect.minY + point.y * scale
            )
        }

        func imagePoint(fromViewPoint point: CGPoint) -> CGPoint {
            CGPoint(
                x: (point.x - imageRect.minX) / scale,
                y: (point.y - imageRect.minY) / scale
            )
        }

        func viewRect(fromImageRect rect: CGRect) -> CGRect {
            CGRect(
                x: imageRect.minX + rect.minX * scale,
                y: imageRect.minY + rect.minY * scale,
                width: rect.width * scale,
                height: rect.height * scale
            )
        }

        func imageRect(fromViewRect rect: CGRect) -> CGRect {
            CGRect(
                x: (rect.minX - imageRect.minX) / scale,
                y: (rect.minY - imageRect.minY) / scale,
                width: rect.width / scale,
                height: rect.height / scale
            )
        }

        func viewLength(fromImageLength length: CGFloat) -> CGFloat { length * scale }
        func imageLength(fromViewLength length: CGFloat) -> CGFloat { length / scale }
    }

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
    private var symbolTool: SymbolTool?

    private let ciContext = CIContext()
    private var scrollObserver: NSObjectProtocol?
    private var isPanning = false
    private var isTemporarySelectInteraction = false
    private var panStartLocation: CGPoint = .zero
    private var panStartOrigin: CGPoint = .zero

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    deinit {
        if let scrollObserver {
            NotificationCenter.default.removeObserver(scrollObserver)
        }
    }

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
        symbolTool = SymbolTool(state: state)
        observeState()
    }

    private func observeState() {
        withObservationTracking {
            _ = state?.annotations
            _ = state?.activeTool
            _ = state?.baseImage
            _ = state?.zoomScale
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.updateCanvasLayout()
                self?.needsDisplay = true
                self?.observeState()
            }
        }
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        configureScrollObservation()
        updateCanvasLayout()
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
        case .symbol:        return symbolTool
        case nil:            return nil
        }
    }

    private func interactionTool(for event: NSEvent, point: CGPoint) -> any DrawingTool {
        if event.modifierFlags.contains(.command),
           state?.activeTool != .select,
           annotationIndex(atViewPoint: point) != nil,
           let selectTool {
            isTemporarySelectInteraction = true
            return selectTool
        }
        isTemporarySelectInteraction = false
        return activeTool() ?? selectTool!
    }

    private func currentInteractionTool() -> any DrawingTool {
        if isTemporarySelectInteraction, let selectTool {
            return selectTool
        }
        return activeTool() ?? selectTool!
    }

    func finalizeActiveTool() {
        activeTool()?.endEditing()
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        if beginPanIfNeeded(with: event) { return }
        let p = convert(event.locationInWindow, from: nil)
        let tool = interactionTool(for: event, point: p)
        tool.mouseDown(at: p, in: self)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        if handlePanDrag(with: event) { return }
        let p = convert(event.locationInWindow, from: nil)
        currentInteractionTool().mouseDragged(to: p, modifierFlags: event.modifierFlags)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if endPanIfNeeded() { return }
        let p = convert(event.locationInWindow, from: nil)
        let tool = currentInteractionTool()
        tool.mouseUp(at: p, in: self)
        if isTemporarySelectInteraction {
            tool.endEditing()
            isTemporarySelectInteraction = false
        }
        needsDisplay = true
    }

    override func otherMouseDown(with event: NSEvent) {
        _ = beginPanIfNeeded(with: event, force: true)
    }

    override func otherMouseDragged(with event: NSEvent) {
        _ = handlePanDrag(with: event)
    }

    override func otherMouseUp(with event: NSEvent) {
        _ = endPanIfNeeded()
    }

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            applyZoomFromScroll(event)
            return
        }
        super.scrollWheel(with: event)
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
            let imageRect = canvasTransform(for: image).imageRect
            NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)).draw(in: imageRect)
        } else {
            NSColor.windowBackgroundColor.setFill()
            bounds.fill()
        }

        state.annotations
            .map(viewAnnotation(fromStoredAnnotation:))
            .forEach { drawAnnotation($0, in: ctx) }
        activeTool()?.drawInProgress(in: ctx)
    }

    func canvasTransform() -> CanvasTransform? {
        guard let image = state?.baseImage else { return nil }
        return canvasTransform(for: image)
    }

    func annotationIndex(atViewPoint point: CGPoint) -> Int? {
        guard let state else { return nil }
        for (index, annotation) in state.annotations.enumerated().reversed() {
            if viewAnnotation(fromStoredAnnotation: annotation).contains(point) {
                return index
            }
        }
        return nil
    }

    func viewAnnotation(at index: Int) -> Annotation? {
        guard let state, index < state.annotations.count else { return nil }
        return viewAnnotation(fromStoredAnnotation: state.annotations[index])
    }

    func storedAnnotation(fromViewAnnotation annotation: Annotation) -> Annotation {
        guard let transform = canvasTransform() else { return annotation }
        switch annotation {
        case let .path(path, color, width):
            var affine = CGAffineTransform.identity
            affine = affine.translatedBy(x: -transform.imageRect.minX, y: -transform.imageRect.minY)
            affine = affine.scaledBy(x: 1 / transform.scale, y: 1 / transform.scale)
            return .path(path.copy(using: &affine) ?? path, color, transform.imageLength(fromViewLength: width))
        case let .text(string, font, color, rect):
            return .text(
                string,
                font.withSize(transform.imageLength(fromViewLength: font.pointSize)),
                color,
                transform.imageRect(fromViewRect: rect)
            )
        case let .stepMarker(number, center, radius):
            return .stepMarker(number, transform.imagePoint(fromViewPoint: center),
                               transform.imageLength(fromViewLength: radius))
        case let .arrow(start, end, color, width):
            return .arrow(
                transform.imagePoint(fromViewPoint: start),
                transform.imagePoint(fromViewPoint: end),
                color,
                transform.imageLength(fromViewLength: width)
            )
        case let .rect(rect, color, width, fill):
            return .rect(transform.imageRect(fromViewRect: rect), color,
                         transform.imageLength(fromViewLength: width), fill)
        case let .ellipse(rect, color, width, fill):
            return .ellipse(transform.imageRect(fromViewRect: rect), color,
                            transform.imageLength(fromViewLength: width), fill)
        case let .blur(rect, kind):
            return .blur(transform.imageRect(fromViewRect: rect), kind)
        case let .zoomBubble(center, radius, zoomLevel):
            return .zoomBubble(transform.imagePoint(fromViewPoint: center),
                               transform.imageLength(fromViewLength: radius), zoomLevel)
        case let .symbol(kind, rect, color):
            return .symbol(kind, transform.imageRect(fromViewRect: rect), color)
        }
    }

    func viewAnnotation(fromStoredAnnotation annotation: Annotation) -> Annotation {
        guard let transform = canvasTransform() else { return annotation }
        switch annotation {
        case let .path(path, color, width):
            var affine = CGAffineTransform.identity
            affine = affine.scaledBy(x: transform.scale, y: transform.scale)
            affine = affine.translatedBy(x: transform.imageRect.minX / transform.scale,
                                         y: transform.imageRect.minY / transform.scale)
            return .path(path.copy(using: &affine) ?? path, color, transform.viewLength(fromImageLength: width))
        case let .text(string, font, color, rect):
            return .text(
                string,
                font.withSize(transform.viewLength(fromImageLength: font.pointSize)),
                color,
                transform.viewRect(fromImageRect: rect)
            )
        case let .stepMarker(number, center, radius):
            return .stepMarker(number, transform.viewPoint(fromImagePoint: center),
                               transform.viewLength(fromImageLength: radius))
        case let .arrow(start, end, color, width):
            return .arrow(
                transform.viewPoint(fromImagePoint: start),
                transform.viewPoint(fromImagePoint: end),
                color,
                transform.viewLength(fromImageLength: width)
            )
        case let .rect(rect, color, width, fill):
            return .rect(transform.viewRect(fromImageRect: rect), color,
                         transform.viewLength(fromImageLength: width), fill)
        case let .ellipse(rect, color, width, fill):
            return .ellipse(transform.viewRect(fromImageRect: rect), color,
                            transform.viewLength(fromImageLength: width), fill)
        case let .blur(rect, kind):
            return .blur(transform.viewRect(fromImageRect: rect), kind)
        case let .zoomBubble(center, radius, zoomLevel):
            return .zoomBubble(transform.viewPoint(fromImagePoint: center),
                               transform.viewLength(fromImageLength: radius), zoomLevel)
        case let .symbol(kind, rect, color):
            return .symbol(kind, transform.viewRect(fromImageRect: rect), color)
        }
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
        case let .symbol(kind, rect, color):
            Annotation.drawSymbol(kind: kind, in: rect, color: color, context: ctx)
        }
    }

    private func drawBlur(rect: CGRect, kind: BlurKind, baseImage: CGImage, in ctx: CGContext) {
        guard let transform = canvasTransform() else { return }
        let imageRect = transform.imageRect(fromViewRect: rect).integral
        guard let cropped = baseImage.cropping(to: imageRect) else { return }
        guard let result = applyBlurFilter(to: cropped, kind: kind) else { return }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        ctx.saveGState()
        ctx.clip(to: rect)
        NSImage(cgImage: result, size: rect.size).draw(in: rect)
        ctx.restoreGState()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawZoomBubble(center: CGPoint, radius: CGFloat, zoomLevel: CGFloat,
                                baseImage: CGImage, in ctx: CGContext) {
        let bubbleRect = CGRect(x: center.x - radius, y: center.y - radius,
                                width: radius * 2, height: radius * 2)
        let circlePath = CGPath(ellipseIn: bubbleRect, transform: nil)

        guard let transform = canvasTransform() else { return }
        let sourceDiameter = transform.imageLength(fromViewLength: (radius * 2) / zoomLevel)
        let sourceCenter = transform.imagePoint(fromViewPoint: center)
        let cropRect = CGRect(
            x: sourceCenter.x - sourceDiameter / 2,
            y: sourceCenter.y - sourceDiameter / 2,
            width: sourceDiameter,
            height: sourceDiameter
        ).integral.intersection(CGRect(origin: .zero, size: CGSize(width: baseImage.width, height: baseImage.height)))

        guard let cropped = baseImage.cropping(to: cropRect), !cropRect.isEmpty else { return }

        ctx.saveGState()
        ctx.addPath(circlePath)
        ctx.clip()
        NSImage(cgImage: cropped, size: NSSize(width: cropRect.width, height: cropRect.height)).draw(in: bubbleRect)
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

    private func canvasTransform(for image: CGImage) -> CanvasTransform {
        CanvasTransform(
            imageSize: CGSize(width: image.width, height: image.height),
            bounds: bounds
        )
    }

    private func configureScrollObservation() {
        guard let scrollView = enclosingScrollView else { return }
        scrollView.contentView.postsBoundsChangedNotifications = true
        if let scrollObserver {
            NotificationCenter.default.removeObserver(scrollObserver)
        }
        scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            self?.updateCanvasLayout()
        }
    }

    private func updateCanvasLayout() {
        guard let state, let image = state.baseImage else { return }
        let viewport = enclosingScrollView?.contentView.bounds.size ?? bounds.size
        guard viewport.width > 0, viewport.height > 0 else { return }

        let imageSize = CGSize(width: image.width, height: image.height)
        let fitScale = min(viewport.width / imageSize.width, viewport.height / imageSize.height, 1.0)
        let displayScale = fitScale * max(state.zoomScale, 0.25)
        let displaySize = CGSize(width: imageSize.width * displayScale,
                                 height: imageSize.height * displayScale)
        let canvasSize = CGSize(width: max(displaySize.width, viewport.width),
                                height: max(displaySize.height, viewport.height))

        if abs(frame.width - canvasSize.width) > 0.5 || abs(frame.height - canvasSize.height) > 0.5 {
            setFrameSize(canvasSize)
        }
        needsDisplay = true
    }

    private func beginPanIfNeeded(with event: NSEvent, force: Bool = false) -> Bool {
        guard let clipView = enclosingScrollView?.contentView else { return false }
        let shouldPan = force || event.modifierFlags.contains(.option)
        guard shouldPan else { return false }
        isPanning = true
        panStartLocation = event.locationInWindow
        panStartOrigin = clipView.bounds.origin
        NSCursor.closedHand.push()
        return true
    }

    private func handlePanDrag(with event: NSEvent) -> Bool {
        guard isPanning, let clipView = enclosingScrollView?.contentView else { return false }
        let location = event.locationInWindow
        let dx = location.x - panStartLocation.x
        let dy = location.y - panStartLocation.y
        let target = CGPoint(x: panStartOrigin.x - dx, y: panStartOrigin.y - dy)
        clipView.scroll(to: clampedContentOrigin(target, in: clipView))
        enclosingScrollView?.reflectScrolledClipView(clipView)
        return true
    }

    private func endPanIfNeeded() -> Bool {
        guard isPanning else { return false }
        isPanning = false
        NSCursor.pop()
        return true
    }

    private func applyZoomFromScroll(_ event: NSEvent) {
        guard let state, let clipView = enclosingScrollView?.contentView else { return }
        let oldScale = max(state.zoomScale, 0.25)
        let delta = event.scrollingDeltaY != 0 ? -event.scrollingDeltaY : event.scrollingDeltaX
        let factor = 1 + (delta * 0.03)
        let newScale = min(4.0, max(0.25, oldScale * factor))
        guard abs(newScale - oldScale) > 0.0001 else { return }

        let oldCenter = CGPoint(x: clipView.bounds.midX, y: clipView.bounds.midY)
        state.zoomScale = newScale
        layoutSubtreeIfNeeded()
        updateCanvasLayout()

        let scaleRatio = newScale / oldScale
        let newCenter = CGPoint(x: oldCenter.x * scaleRatio, y: oldCenter.y * scaleRatio)
        let newOrigin = CGPoint(x: newCenter.x - clipView.bounds.width / 2,
                                y: newCenter.y - clipView.bounds.height / 2)
        clipView.scroll(to: clampedContentOrigin(newOrigin, in: clipView))
        enclosingScrollView?.reflectScrolledClipView(clipView)
    }

    private func clampedContentOrigin(_ proposed: CGPoint, in clipView: NSClipView) -> CGPoint {
        let maxX = max(0, bounds.width - clipView.bounds.width)
        let maxY = max(0, bounds.height - clipView.bounds.height)
        return CGPoint(x: min(max(proposed.x, 0), maxX),
                       y: min(max(proposed.y, 0), maxY))
    }
}
