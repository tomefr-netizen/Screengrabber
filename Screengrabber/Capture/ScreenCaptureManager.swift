import AppKit
import CoreGraphics

class ScreenCaptureManager {
    static let shared = ScreenCaptureManager()
    private var overlayWindow: CaptureOverlayWindow?
    private var pendingCaptureWorkItem: DispatchWorkItem?

    func beginCapture(delay: TimeInterval = 0, completion: @escaping (CGImage) -> Void) {
        pendingCaptureWorkItem?.cancel()
        if delay > 0 {
            let workItem = DispatchWorkItem { [weak self] in
                self?.capture(completion: completion)
            }
            pendingCaptureWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        } else {
            pendingCaptureWorkItem = nil
            capture(completion: completion)
        }
    }

    func cancelCapture() {
        pendingCaptureWorkItem?.cancel()
        pendingCaptureWorkItem = nil
        dismissOverlay()
    }

    private func capture(completion: @escaping (CGImage) -> Void) {
        pendingCaptureWorkItem = nil
        dismissOverlay()
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
        guard let fullImage = CGDisplayCreateImage(displayID) else { return }

        let overlay = CaptureOverlayWindow(screenImage: fullImage, screen: screen)
        overlay.onSelection = { [weak self] rect in
            self?.dismissOverlay()
            let scale = screen.backingScaleFactor
            if let cropped = self?.crop(fullImage, rect: rect, scale: scale, imageHeight: CGFloat(fullImage.height)) {
                completion(cropped)
            }
        }
        overlay.onCancel = { [weak self] in
            self?.cancelCapture()
        }
        overlayWindow = overlay
        NSApp.activate(ignoringOtherApps: true)
        overlay.makeKeyAndOrderFront(nil)
        overlay.makeFirstResponder(overlay.contentView)
    }

    private func dismissOverlay() {
        guard let overlay = overlayWindow else { return }
        overlayWindow = nil
        overlay.onSelection = nil
        overlay.onCancel = nil
        overlay.contentView = nil
        overlay.orderOut(nil)
    }

    private func crop(_ image: CGImage, rect: NSRect, scale: CGFloat, imageHeight: CGFloat) -> CGImage? {
        // RegionSelectorView uses isFlipped=true (top-left origin, y-down)
        // CGImage.cropping expects rect in image pixel space:
        // (0,0) = top-left for CGDisplayCreateImage output
        let pixelRect = CGRect(
            x: rect.minX * scale,
            y: rect.minY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
        return image.cropping(to: pixelRect)
    }
}
