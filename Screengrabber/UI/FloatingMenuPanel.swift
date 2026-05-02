import AppKit
import SwiftUI

private class PanelHostingView<Content: View>: NSHostingView<Content> {
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

class FloatingMenuPanel: NSPanel {
    private let state: DrawingState
    private var hostingView: PanelHostingView<FloatingMenuView>?

    override var canBecomeKey: Bool { true }

    init(state: DrawingState) {
        self.state = state
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 44),
            styleMask: [.nonactivatingPanel, .titled, .closable, .hudWindow],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        title = "Screengrabber"
        isMovableByWindowBackground = true
        hidesOnDeactivate = false   // must stay visible when other apps are active
        collectionBehavior = [.canJoinAllSpaces, .stationary]

        let view = FloatingMenuView(state: state)
        let hosting = PanelHostingView(rootView: view)
        hostingView = hosting
        contentView = hosting

        positionNearTopRight()
    }

    func show() {
        orderFrontRegardless()  // works for background (LSUIElement) apps
    }

    private func positionNearTopRight() {
        guard let screen = NSScreen.main else { return }
        let x = screen.visibleFrame.midX - frame.width / 2
        let y = screen.visibleFrame.midY - frame.height / 2
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

struct FloatingMenuView: View {
    @State private var captureDelay: TimeInterval = 0
    var state: DrawingState

    var body: some View {
        HStack(spacing: 6) {
            Button("Ny") {
                NotificationCenter.default.post(name: .newImageRequested, object: nil)
            }

            Button("Spara") {
                NotificationCenter.default.post(name: .saveRequested, object: nil)
            }
            .disabled(!state.hasImage)

            Divider().frame(height: 20)

            Menu {
                Button("Utan fördröjning") { captureDelay = 0 }
                Divider()
                Button("2 sekunder")  { captureDelay = 2 }
                Button("5 sekunder")  { captureDelay = 5 }
                Button("10 sekunder") { captureDelay = 10 }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "timer")
                    Text(captureDelay == 0 ? "Nu" : "\(Int(captureDelay))s")
                        .frame(width: 22, alignment: .leading)
                }
            }
            .frame(width: 70)
            .onChange(of: captureDelay) { _, newValue in
                NotificationCenter.default.post(name: .captureDelayChanged, object: newValue)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
    }
}

extension Notification.Name {
    static let newImageRequested   = Notification.Name("newImageRequested")
    static let saveRequested       = Notification.Name("saveRequested")
    static let captureDelayChanged = Notification.Name("captureDelayChanged")
}
