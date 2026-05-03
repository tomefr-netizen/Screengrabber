import AppKit
import SwiftUI

class EditorWindowController: NSWindowController {
    private let state: DrawingState
    private(set) var canvasView: CanvasView?
    private var scrollView: NSScrollView?

    init(state: DrawingState) {
        self.state = state
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Screengrabber"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildContent() {
        guard let window else { return }

        let canvas = CanvasView()
        canvas.setup(state: state)
        canvasView = canvas

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .windowBackgroundColor
        scrollView.documentView = canvas
        self.scrollView = scrollView

        let toolbar = NSHostingView(rootView: EditorToolbarView(state: state))
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        canvas.translatesAutoresizingMaskIntoConstraints = true

        let stack = NSStackView(views: [toolbar, scrollView])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.distribution = .fill
        NSLayoutConstraint.activate([
            toolbar.heightAnchor.constraint(equalToConstant: 44)
        ])
        window.contentView = stack
    }

    func loadImage(_ image: CGImage) {
        guard let window else { return }
        let imageW = CGFloat(image.width)
        let imageH = CGFloat(image.height)
        let screen = window.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let maxW = screen.visibleFrame.width * 0.92
        let maxH = (screen.visibleFrame.height - 44) * 0.92
        let scale = min(maxW / imageW, maxH / imageH, 1.0)
        let contentSize = NSSize(width: imageW * scale, height: imageH * scale + 44)
        state.zoomScale = 1.0
        window.setContentSize(contentSize)
        window.center()
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(canvasView)
        canvasView?.frame = CGRect(origin: .zero, size: NSSize(width: imageW * scale, height: imageH * scale))
    }
}
