import AppKit
import ImageIO
import UniformTypeIdentifiers
import CoreText
import CoreImage

enum ExportFormat: Equatable {
    case avif, png

    var utType: UTType {
        switch self {
        case .avif: return UTType(importedAs: "public.avif")
        case .png:  return .png
        }
    }
    var fileExtension: String { self == .avif ? "avif" : "png" }
}

class ImageExporter {
    static func export(state: DrawingState, completion: ((Bool) -> Void)? = nil) {
        guard let base = state.baseImage else {
            showRenderError()
            completion?(false)
            return
        }
        guard let rendered = render(base: base, annotations: state.annotations) else {
            showRenderError()
            completion?(false)
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Screenshot-\(formatter.string(from: Date())).avif"
        panel.allowedContentTypes = [ExportFormat.avif.utType, .png]
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion?(false)
                return
            }
            let format = requestedFormat(for: panel, url: url)
            let destinationURL = normalizedDestinationURL(for: url, format: format)
            completion?(write(image: rendered, to: destinationURL, format: format))
        }
    }

    static func copyToPasteboard(state: DrawingState, format: ExportFormat) {
        guard let base = state.baseImage else { return }
        guard let rendered = render(base: base, annotations: state.annotations) else { return }
        guard let encoded = encodedData(for: rendered, format: format) else {
            showWriteError(url: URL(fileURLWithPath: format == .avif ? "Clipboard.avif" : "Clipboard.png"))
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(encoded, forType: NSPasteboard.PasteboardType(format.utType.identifier))

        if format == .png {
            let image = NSImage(cgImage: rendered, size: NSSize(width: rendered.width, height: rendered.height))
            pasteboard.writeObjects([image])
        }
    }

    static func render(base: CGImage, annotations: [Annotation]) -> CGImage? {
        let w = base.width, h = base.height
        guard let cs = base.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: nil, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: cs,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }

        // Draw base image via NSImage — handles CGImage↔CGContext coordinate flip correctly
        let nsBase = NSImage(cgImage: base, size: NSSize(width: CGFloat(w), height: CGFloat(h)))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        nsBase.draw(in: NSRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
        NSGraphicsContext.restoreGraphicsState()

        // Draw annotations: flip y + scale from view-point space to image-pixel space
        ctx.saveGState()
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        let ciCtx = CIContext()
        for annotation in annotations {
            switch annotation {
            case let .path(path, color, width):
                ctx.setStrokeColor(color.cgColor)
                ctx.setLineWidth(width)
                ctx.setLineCap(.round)
                ctx.setLineJoin(.round)
                ctx.addPath(path)
                ctx.strokePath()

            case let .text(string, font, color, rect):
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let attributed = NSAttributedString(string: string, attributes: attrs)
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
                attributed.draw(in: rect)
                NSGraphicsContext.restoreGraphicsState()

            case let .stepMarker(number, center, radius):
                ctx.setFillColor(NSColor.systemRed.cgColor)
                ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                           width: radius * 2, height: radius * 2))
                let fontSize = radius * 1.1
                let boldFont = NSFont.boldSystemFont(ofSize: fontSize)
                let attrStr = NSAttributedString(string: "\(number)", attributes: [
                    .font: boldFont, .foregroundColor: NSColor.white
                ])
                let ctLine = CTLineCreateWithAttributedString(attrStr)
                let lineBounds = CTLineGetBoundsWithOptions(ctLine, [])
                ctx.saveGState()
                ctx.translateBy(x: center.x - lineBounds.width / 2,
                                y: center.y + lineBounds.height / 2)
                ctx.scaleBy(x: 1, y: -1)
                ctx.textPosition = CGPoint(x: 0, y: 0)
                CTLineDraw(ctLine, ctx)
                ctx.restoreGState()

            case let .arrow(start, end, color, width):
                Annotation.drawArrow(from: start, to: end, color: color, width: width, in: ctx)

            case let .rect(rect, color, width, fill):
                if let fill {
                    ctx.setFillColor(fill.cgColor)
                    ctx.fill(rect)
                }
                if width > 0 {
                    ctx.setStrokeColor(color.cgColor)
                    ctx.setLineWidth(width)
                    ctx.stroke(rect)
                }

            case let .ellipse(rect, color, width, fill):
                if let fill {
                    ctx.setFillColor(fill.cgColor)
                    ctx.fillEllipse(in: rect)
                }
                if width > 0 {
                    ctx.setStrokeColor(color.cgColor)
                    ctx.setLineWidth(width)
                    ctx.strokeEllipse(in: rect)
                }

            case let .blur(blurRect, kind):
                let cropRect = blurRect.integral
                if let cropped = base.cropping(to: cropRect),
                   let result = applyBlurFilter(to: cropped, kind: kind, ciContext: ciCtx) {
                    ctx.draw(result, in: blurRect)
                }

            case let .zoomBubble(center, radius, zoomLevel):
                let sourceW = (radius * 2) / zoomLevel, sourceH = (radius * 2) / zoomLevel
                let cropRect = CGRect(x: center.x - sourceW / 2,
                                      y: center.y - sourceH / 2,
                                      width: sourceW, height: sourceH).integral
                guard let cropped = base.cropping(to: cropRect) else { break }
                let bubbleRect = CGRect(x: center.x - radius, y: center.y - radius,
                                        width: radius * 2, height: radius * 2)
                let circlePath = CGPath(ellipseIn: bubbleRect, transform: nil)
                ctx.saveGState()
                ctx.addPath(circlePath)
                ctx.clip()
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
                NSImage(cgImage: cropped, size: NSSize(width: cropRect.width, height: cropRect.height))
                    .draw(in: bubbleRect)
                NSGraphicsContext.restoreGraphicsState()
                ctx.restoreGState()
                // Border (inside flip transform, stroke in view coords)
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

            case let .symbol(kind, rect, color):
                Annotation.drawSymbol(kind: kind, in: rect, color: color, context: ctx)
            }
        }
        ctx.restoreGState()

        return ctx.makeImage()
    }

    private static func applyBlurFilter(to image: CGImage, kind: BlurKind,
                                        ciContext: CIContext) -> CGImage? {
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

    private static func requestedFormat(for panel: NSSavePanel, url: URL) -> ExportFormat {
        let lowercasedName = panel.nameFieldStringValue.lowercased()
        if lowercasedName.hasSuffix(".png") || url.pathExtension.lowercased() == "png" {
            return .png
        }
        return .avif
    }

    private static func normalizedDestinationURL(for url: URL, format: ExportFormat) -> URL {
        let expectedExtension = format.fileExtension
        if url.pathExtension.lowercased() == expectedExtension {
            return url
        }
        if url.pathExtension.isEmpty {
            return url.appendingPathExtension(expectedExtension)
        }
        return url.deletingPathExtension().appendingPathExtension(expectedExtension)
    }

    private static func write(image: CGImage, to url: URL, format: ExportFormat) -> Bool {
        NSLog("Screengrabber: Writing type=\(format.utType.identifier) to \(url.path)")
        let typeId = format.utType.identifier as CFString
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, typeId, 1, nil) else {
            NSLog("Screengrabber: destination creation failed, falling back to PNG")
            let pngURL = url.deletingPathExtension().appendingPathExtension("png")
            guard let pngDest = CGImageDestinationCreateWithURL(
                pngURL as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil
            ) else {
                showWriteError(url: url)
                return false
            }
            CGImageDestinationAddImage(pngDest, image, nil)
            let finalized = CGImageDestinationFinalize(pngDest)
            NSLog("Screengrabber: png fallback finalize=\(finalized ? 1 : 0) path=\(pngURL.path)")
            if finalized {
                return true
            } else {
                showWriteError(url: pngURL)
                return false
            }
        }
        let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.92]
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        let finalized = CGImageDestinationFinalize(dest)
        NSLog("Screengrabber: finalize=\(finalized ? 1 : 0) path=\(url.path)")
        if finalized {
            return true
        } else {
            showWriteError(url: url)
            return false
        }
    }

    private static func encodedData(for image: CGImage, format: ExportFormat) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, format.utType.identifier as CFString, 1, nil) else {
            return nil
        }
        let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.92]
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    private static func showWriteError(url: URL) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Kunde inte spara"
            alert.informativeText = "Filen \(url.lastPathComponent) kunde inte skrivas."
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    private static func showRenderError() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Kunde inte skapa bild"
            alert.informativeText = "Exporten kunde inte renderas. Prova igen eller ta bort senaste objektet om problemet kvarstår."
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
