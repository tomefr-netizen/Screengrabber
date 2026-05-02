import AppKit
import CoreGraphics

class ScreenCaptureManager {
    static let shared = ScreenCaptureManager()
    private var overlayWindow: CaptureOverlayWindow?

    func beginCapture(delay: TimeInterval = 0, completion: @escaping (CGImage) -> Void) {
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.capture(completion: completion)
            }
        } else {
            capture(completion: completion)
        }
    }

    private func capture(completion: @escaping (CGImage) -> Void) {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
        guard let fullImage = CGDisplayCreateImage(displayID) else { return }

        let overlay = CaptureOverlayWindow(screenImage: fullImage, screen: screen)
        overlay.onSelection = { [weak overlay, weak self] rect in
            overlay?.orderOut(nil)
            self?.overlayWindow = nil
            let scale = screen.backingScaleFactor
            if let cropped = self?.crop(fullImage, rect: rect, scale: scale, imageHeight: CGFloat(fullImage.height)) {
                completion(cropped)
            }
        }
        overlayWindow = overlay
        overlay.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        overlay.makeFirstResponder(overlay.contentView)
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
