import CoreGraphics
import AppKit

enum BlurKind {
    case gaussian(radius: CGFloat)
    case pixelate(scale: CGFloat)
}

enum Annotation {
    case path(CGPath, NSColor, CGFloat)
    case text(String, NSFont, NSColor, CGRect)
    case stepMarker(Int, CGPoint, CGFloat)             // number, center, radius
    case arrow(CGPoint, CGPoint, NSColor, CGFloat)     // start, end, color, lineWidth
    case rect(CGRect, NSColor, CGFloat, NSColor?)      // rect, strokeColor, strokeWidth, fillColor?
    case ellipse(CGRect, NSColor, CGFloat, NSColor?)   // boundingRect, strokeColor, strokeWidth, fillColor?
    case blur(CGRect, BlurKind)
    case zoomBubble(CGPoint, CGFloat, CGFloat)         // center, radius, zoomLevel
    case symbol(SymbolKind, CGRect, NSColor)           // kind, rect, color

    enum ResizeHandle {
        case bottomRight
        case radial
    }

    func contains(_ point: CGPoint) -> Bool {
        switch self {
        case let .text(_, _, _, rect):
            return rect.insetBy(dx: -8, dy: -8).contains(point)
        case let .path(path, _, width):
            let stroked = path.copy(strokingWithWidth: width + 12,
                                    lineCap: .round, lineJoin: .round, miterLimit: 4)
            return stroked.contains(point)
        case let .stepMarker(_, center, radius):
            let dx = point.x - center.x, dy = point.y - center.y
            return dx * dx + dy * dy <= (radius + 6) * (radius + 6)
        case let .arrow(start, end, _, width):
            let tolerance = width + 6
            let dx = end.x - start.x, dy = end.y - start.y
            let len2 = dx * dx + dy * dy
            if len2 == 0 { return hypot(point.x - start.x, point.y - start.y) < tolerance }
            let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / len2))
            return hypot(point.x - (start.x + t * dx), point.y - (start.y + t * dy)) < tolerance
        case let .rect(r, _, width, fill):
            let outer = r.insetBy(dx: -(width / 2 + 6), dy: -(width / 2 + 6))
            if fill != nil { return outer.contains(point) }
            let inner = r.insetBy(dx: width + 6, dy: width + 6)
            return outer.contains(point) && !inner.contains(point)
        case let .ellipse(r, _, width, fill):
            let cx = r.midX, cy = r.midY
            let rxO = r.width / 2 + width + 6, ryO = r.height / 2 + width + 6
            if fill != nil {
                return pow((point.x - cx) / rxO, 2) + pow((point.y - cy) / ryO, 2) <= 1
            }
            let rxI = max(0, r.width / 2 - width - 6), ryI = max(0, r.height / 2 - width - 6)
            let normO = pow((point.x - cx) / rxO, 2) + pow((point.y - cy) / ryO, 2)
            let normI = rxI > 0 ? pow((point.x - cx) / rxI, 2) + pow((point.y - cy) / ryI, 2) : 2.0
            return normO <= 1 && normI >= 1
        case let .blur(rect, _):
            return rect.contains(point)
        case let .zoomBubble(center, radius, _):
            let dx = point.x - center.x, dy = point.y - center.y
            return dx * dx + dy * dy <= radius * radius
        case let .symbol(_, rect, _):
            return rect.insetBy(dx: -8, dy: -8).contains(point)
        }
    }

    func moved(by offset: CGVector) -> Annotation {
        switch self {
        case let .text(s, f, c, r):
            return .text(s, f, c, r.offsetBy(dx: offset.dx, dy: offset.dy))
        case let .path(path, c, w):
            var t = CGAffineTransform(translationX: offset.dx, y: offset.dy)
            return .path(path.copy(using: &t) ?? path, c, w)
        case let .stepMarker(n, center, r):
            return .stepMarker(n, CGPoint(x: center.x + offset.dx, y: center.y + offset.dy), r)
        case let .arrow(s, e, c, w):
            return .arrow(CGPoint(x: s.x + offset.dx, y: s.y + offset.dy),
                          CGPoint(x: e.x + offset.dx, y: e.y + offset.dy), c, w)
        case let .rect(r, c, w, fill):
            return .rect(r.offsetBy(dx: offset.dx, dy: offset.dy), c, w, fill)
        case let .ellipse(r, c, w, fill):
            return .ellipse(r.offsetBy(dx: offset.dx, dy: offset.dy), c, w, fill)
        case let .blur(r, kind):
            return .blur(r.offsetBy(dx: offset.dx, dy: offset.dy), kind)
        case let .zoomBubble(center, radius, zoom):
            return .zoomBubble(CGPoint(x: center.x + offset.dx, y: center.y + offset.dy), radius, zoom)
        case let .symbol(kind, rect, color):
            return .symbol(kind, rect.offsetBy(dx: offset.dx, dy: offset.dy), color)
        }
    }

    var boundingRect: CGRect {
        switch self {
        case let .text(_, _, _, rect):
            return rect
        case let .path(path, _, width):
            return path.boundingBoxOfPath.insetBy(dx: -width / 2, dy: -width / 2)
        case let .stepMarker(_, center, radius):
            return CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        case let .arrow(start, end, _, width):
            let minX = min(start.x, end.x), minY = min(start.y, end.y)
            let maxX = max(start.x, end.x), maxY = max(start.y, end.y)
            let pad = width / 2
            return CGRect(x: minX - pad, y: minY - pad, width: maxX - minX + pad * 2, height: maxY - minY + pad * 2)
        case let .rect(rect, _, width, _):
            return rect.insetBy(dx: -width / 2, dy: -width / 2)
        case let .ellipse(rect, _, width, _):
            return rect.insetBy(dx: -width / 2, dy: -width / 2)
        case let .blur(rect, _):
            return rect
        case let .zoomBubble(center, radius, _):
            return CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        case let .symbol(_, rect, _):
            return rect
        }
    }

    var resizeHandle: ResizeHandle? {
        switch self {
        case .text, .stepMarker, .rect, .ellipse, .blur, .symbol:
            return .bottomRight
        case .zoomBubble:
            return .radial
        case .path, .arrow:
            return nil
        }
    }

    func resizeHandleCenter() -> CGPoint? {
        switch self {
        case let .zoomBubble(center, radius, _):
            return CGPoint(x: center.x + radius, y: center.y)
        default:
            guard resizeHandle != nil else { return nil }
            return CGPoint(x: boundingRect.maxX, y: boundingRect.maxY)
        }
    }

    func resized(byDraggingTo point: CGPoint) -> Annotation {
        let minimumSide: CGFloat = 18
        let minimumRadius: CGFloat = 12

        switch self {
        case let .text(string, font, color, rect):
            return .text(string, font, color, CGRect(x: rect.minX, y: rect.minY,
                                                     width: max(minimumSide, point.x - rect.minX),
                                                     height: max(minimumSide, point.y - rect.minY)))
        case let .stepMarker(number, center, _):
            return .stepMarker(number, center, max(minimumRadius, hypot(point.x - center.x, point.y - center.y)))
        case let .rect(rect, stroke, width, fill):
            return .rect(CGRect(x: rect.minX, y: rect.minY,
                                width: max(minimumSide, point.x - rect.minX),
                                height: max(minimumSide, point.y - rect.minY)),
                         stroke, width, fill)
        case let .ellipse(rect, stroke, width, fill):
            return .ellipse(CGRect(x: rect.minX, y: rect.minY,
                                   width: max(minimumSide, point.x - rect.minX),
                                   height: max(minimumSide, point.y - rect.minY)),
                            stroke, width, fill)
        case let .blur(rect, kind):
            return .blur(CGRect(x: rect.minX, y: rect.minY,
                                width: max(minimumSide, point.x - rect.minX),
                                height: max(minimumSide, point.y - rect.minY)),
                         kind)
        case let .zoomBubble(center, _, zoom):
            return .zoomBubble(center, max(minimumRadius, hypot(point.x - center.x, point.y - center.y)), zoom)
        case let .symbol(kind, rect, color):
            return .symbol(kind, CGRect(x: rect.minX, y: rect.minY,
                                        width: max(minimumSide, point.x - rect.minX),
                                        height: max(minimumSide, point.y - rect.minY)), color)
        case .path, .arrow:
            return self
        }
    }

    static func drawSymbol(kind: SymbolKind, in rect: CGRect, color: NSColor, context: CGContext) {
        let strokeWidth = max(2, min(rect.width, rect.height) * 0.12)
        let inset = strokeWidth * 0.8
        let inner = rect.insetBy(dx: inset, dy: inset)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: inner.minX + inner.width * x, y: inner.minY + inner.height * y)
        }

        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
        context.setLineWidth(strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch kind {
        case .checkmark:
            context.move(to: point(0.12, 0.48))
            context.addLine(to: point(0.40, 0.82))
            context.addLine(to: point(1.00, 0.10))
            context.strokePath()

        case .cross:
            context.move(to: point(0.00, 0.00))
            context.addLine(to: point(1.00, 1.00))
            context.move(to: point(1.00, 0.00))
            context.addLine(to: point(0.00, 1.00))
            context.strokePath()

        case .info:
            context.strokeEllipse(in: inner)
            let lineWidth = max(2, strokeWidth * 0.9)
            context.setLineWidth(lineWidth)
            context.move(to: point(0.50, 0.24))
            context.addLine(to: point(0.50, 0.58))
            context.strokePath()
            let dotRadius = max(1.5, inner.width * 0.06)
            let dotCenter = point(0.50, 0.76)
            context.fillEllipse(in: CGRect(x: dotCenter.x - dotRadius,
                                           y: dotCenter.y - dotRadius,
                                           width: dotRadius * 2,
                                           height: dotRadius * 2))

        case .warning:
            let triangle = CGMutablePath()
            triangle.move(to: point(0.50, 0.06))
            triangle.addLine(to: point(0.96, 0.94))
            triangle.addLine(to: point(0.04, 0.94))
            triangle.closeSubpath()
            context.addPath(triangle)
            context.strokePath()

            let markWidth = max(2, inner.width * 0.08)
            context.setLineWidth(markWidth)
            context.move(to: point(0.50, 0.34))
            context.addLine(to: point(0.50, 0.66))
            context.strokePath()
            let dotRadius = max(1.5, inner.width * 0.05)
            let dotCenter = point(0.50, 0.80)
            context.fillEllipse(in: CGRect(x: dotCenter.x - dotRadius,
                                           y: dotCenter.y - dotRadius,
                                           width: dotRadius * 2,
                                           height: dotRadius * 2))
        }

        context.restoreGState()
    }

    static func drawArrow(from start: CGPoint, to end: CGPoint,
                          color: NSColor, width: CGFloat, in ctx: CGContext) {
        let dx = end.x - start.x, dy = end.y - start.y
        let len = hypot(dx, dy)
        guard len > 0 else { return }
        let angle = atan2(dy, dx)
        let headLen = max(width * 4, 14)
        let headAngle: CGFloat = 0.42
        let shaftEnd = CGPoint(x: end.x - headLen * 0.75 * cos(angle),
                               y: end.y - headLen * 0.75 * sin(angle))
        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setFillColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.move(to: start)
        ctx.addLine(to: shaftEnd)
        ctx.strokePath()
        ctx.move(to: end)
        ctx.addLine(to: CGPoint(x: end.x - headLen * cos(angle - headAngle),
                                y: end.y - headLen * sin(angle - headAngle)))
        ctx.addLine(to: CGPoint(x: end.x - headLen * cos(angle + headAngle),
                                y: end.y - headLen * sin(angle + headAngle)))
        ctx.closePath()
        ctx.fillPath()
        ctx.restoreGState()
    }
}
