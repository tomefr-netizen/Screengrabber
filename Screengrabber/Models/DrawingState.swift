import Foundation
import AppKit
import Observation

enum ToolType: String, CaseIterable {
    case select, pen, highlighterPen, text, stepMarker, arrow, rect, ellipse, highlight, blur, magnifier, symbol
}

enum SymbolKind: String, CaseIterable {
    case checkmark, cross, info, warning

    var title: String {
        switch self {
        case .checkmark: return "Checkmark"
        case .cross: return "Kryss"
        case .info: return "Info"
        case .warning: return "Varning"
        }
    }

    var symbolName: String {
        switch self {
        case .checkmark: return "checkmark"
        case .cross: return "xmark"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        }
    }
}

enum BlurMode: String, Equatable {
    case gaussian, pixelate
}

@Observable
class DrawingState {
    var baseImage: CGImage?
    var annotations: [Annotation] = []
    var redoStack: [Annotation] = []
    var activeTool: ToolType = .pen
    var activeColor: NSColor = .red
    var lineWidth: CGFloat = 3.0
    var fillEnabled: Bool = false
    var fillColor: NSColor = NSColor.yellow.withAlphaComponent(0.4)
    var blurMode: BlurMode = .gaussian
    var highlighterOpacity: CGFloat = 0.4
    var bubbleZoomLevel: CGFloat = 2.0
    var zoomScale: CGFloat = 1.0
    var selectedSymbol: SymbolKind = .checkmark
    var hasImage: Bool { baseImage != nil }

    func addAnnotation(_ a: Annotation) {
        annotations.append(a)
        redoStack.removeAll()
    }

    func replaceAnnotation(at index: Int, with annotation: Annotation) {
        guard index < annotations.count else { return }
        var updated = annotations
        updated[index] = annotation
        annotations = updated
    }

    func hitTest(_ point: CGPoint) -> Int? {
        for (i, annotation) in annotations.enumerated().reversed() {
            if annotation.contains(point) { return i }
        }
        return nil
    }

    func undo() {
        guard let last = annotations.popLast() else { return }
        redoStack.append(last)
    }

    func redo() {
        guard let last = redoStack.popLast() else { return }
        annotations.append(last)
    }

    func reset() {
        baseImage = nil
        annotations.removeAll()
        redoStack.removeAll()
        zoomScale = 1.0
    }
}
