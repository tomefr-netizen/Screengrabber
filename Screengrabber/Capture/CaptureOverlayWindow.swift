import AppKit

class CaptureOverlayWindow: NSWindow {
    var onSelection: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

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
        selector.onCancel = { [weak self] in
            self?.onCancel?()
        }
        contentView = selector
        makeFirstResponder(selector)
    }
}
