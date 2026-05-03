import Cocoa
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = DrawingState()
    private var editorController: EditorWindowController?
    private var floatingPanel: FloatingMenuPanel?
    private var statusItem: NSStatusItem?
    private var hotKeyRef: EventHotKeyRef?
    private var captureDelay: TimeInterval = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? "Screengrabber started pid=\(ProcessInfo.processInfo.processIdentifier)\n"
            .write(toFile: "/tmp/sg_launch.txt", atomically: true, encoding: .utf8)
        NSLog("Screengrabber: applicationDidFinishLaunching pid=%d", ProcessInfo.processInfo.processIdentifier)
        editorController = EditorWindowController(state: state)
        floatingPanel = FloatingMenuPanel(state: state)
        setupStatusItem()
        registerHotKey()
        setupNotifications()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.floatingPanel?.show()
        }
    }

    // MARK: - Status bar item (reliable menu bar presence)

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder",
                                   accessibilityDescription: "Screengrabber")
            if button.image == nil { button.title = "📷" }
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showStatusMenu()
        } else {
            hotKeyFired()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Ny skärmbild (⌃⇧S)", action: #selector(statusCapture), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Visa panel", action: #selector(showPanel), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        let saveItem = menu.addItem(withTitle: "Spara", action: #selector(handleSave), keyEquivalent: "")
        saveItem.target = self
        saveItem.isEnabled = state.hasImage
        let copyPNGItem = menu.addItem(withTitle: "Kopiera som PNG", action: #selector(handleCopyPNG), keyEquivalent: "")
        copyPNGItem.target = self
        copyPNGItem.isEnabled = state.hasImage
        let copyAVIFItem = menu.addItem(withTitle: "Kopiera som AVIF", action: #selector(handleCopyAVIF), keyEquivalent: "")
        copyAVIFItem.target = self
        copyAVIFItem.isEnabled = state.hasImage
        menu.addItem(.separator())
        menu.addItem(withTitle: "Avsluta", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func statusCapture() { hotKeyFired() }
    @objc private func showPanel()     { floatingPanel?.show() }

    // MARK: - Global hotkey ⌘⇧S via Carbon (no Accessibility permission needed)

    private func registerHotKey() {
        let hkID = EventHotKeyID(signature: 0x53435247, id: 1) // "SCRG"
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_S),
            UInt32(controlKey | shiftKey),
            hkID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        NSLog("Screengrabber: RegisterEventHotKey status=%d ref=%@", status, hotKeyRef != nil ? "ok" : "nil")
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            screengrabberHotKeyHandler,
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )
    }

    // Called from the C-compatible hotkey handler below
    func hotKeyFired() {
        NSLog("Screengrabber: hotKeyFired, screenAccess=%d", CGPreflightScreenCaptureAccess())
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            let alert = NSAlert()
            alert.messageText = "Skärminspelning behövs"
            alert.informativeText = "Gå till Systeminställningar → Integritet & säkerhet → Skärminspelning och aktivera Screengrabber."
            alert.runModal()
            return
        }
        ScreenCaptureManager.shared.beginCapture(delay: captureDelay) { [weak self] image in
            DispatchQueue.main.async {
                guard let self else { return }
                self.state.reset()
                self.state.baseImage = image
                self.editorController?.loadImage(image)
            }
        }
    }

    // MARK: - Notifications

    private func setupNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleSave),        name: .saveRequested,       object: nil)
        nc.addObserver(self, selector: #selector(handleCopyPNG),     name: .copyPNGRequested,    object: nil)
        nc.addObserver(self, selector: #selector(handleCopyAVIF),    name: .copyAVIFRequested,   object: nil)
        nc.addObserver(self, selector: #selector(handleNew),         name: .newImageRequested,   object: nil)
        nc.addObserver(self, selector: #selector(handleDelayChange), name: .captureDelayChanged, object: nil)
    }

    @objc private func handleSave() {
        saveCurrentImage()
    }

    @objc private func handleCopyPNG() {
        editorController?.canvasView?.finalizeActiveTool()
        ImageExporter.copyToPasteboard(state: state, format: .png)
    }

    @objc private func handleCopyAVIF() {
        editorController?.canvasView?.finalizeActiveTool()
        ImageExporter.copyToPasteboard(state: state, format: .avif)
    }

    @objc private func handleNew() {
        editorController?.canvasView?.finalizeActiveTool()
        if state.hasImage && !state.annotations.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Spara bild?"
            alert.informativeText = "Den nuvarande bilden har osparade ändringar."
            alert.addButton(withTitle: "Spara")
            alert.addButton(withTitle: "Kassera")
            alert.addButton(withTitle: "Avbryt")
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                saveCurrentImage { [weak self] saved in
                    guard saved else { return }
                    self?.beginFreshCapture()
                }
            case .alertSecondButtonReturn:
                beginFreshCapture()
            default:
                break
            }
        } else {
            beginFreshCapture()
        }
    }

    @objc private func handleDelayChange(_ note: Notification) {
        captureDelay = (note.object as? TimeInterval) ?? 0
    }

    private func resetEditor() {
        state.reset()
        editorController?.window?.orderOut(nil)
    }

    private func saveCurrentImage(completion: ((Bool) -> Void)? = nil) {
        editorController?.canvasView?.finalizeActiveTool()
        ImageExporter.export(state: state, completion: completion)
    }

    private func beginFreshCapture() {
        resetEditor()
        // Let modal alerts/save panels disappear fully before freezing the next capture.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.hotKeyFired()
        }
    }
}

// Top-level C-compatible function required for Carbon event handler
private func screengrabberHotKeyHandler(
    _: EventHandlerCallRef?,
    _: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let ptr = userData else { return OSStatus(eventNotHandledErr) }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(ptr).takeUnretainedValue()
    DispatchQueue.main.async { delegate.hotKeyFired() }
    return noErr
}
