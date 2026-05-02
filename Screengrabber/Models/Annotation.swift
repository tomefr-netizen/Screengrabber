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
    case zoomBubble(CGPoint, CGFloat, CGFloat)      // center, radius, zoomLevel

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
        }
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
