import AppKit

class CaptureOverlayWindow: NSWindow {
    var onSelection: ((NSRect) -> Void)?

    init(screenImage: CGImage, screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let selector = RegionSelectorView(frame: screen.frame, screenImage: screenImage)
        selector.onSelection = { [weak self] rect in
            self?.onSelection?(rect)
        }
        contentView = selector
        makeFirstResponder(selector)
    }
}
