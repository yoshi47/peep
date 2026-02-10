import AppKit
import SwiftUI
import Combine

/// Controller for a single capture panel window
final class CapturePanelWindowController {
    let item: CaptureItem
    private var window: NSPanel?
    private var hostingView: CapturePanelHostingView<CapturePanelView>?
    private var cancellables = Set<AnyCancellable>()
    private var isClosed = false
    
    var onClose: (() -> Void)?
    
    init(item: CaptureItem) {
        self.item = item
    }
    
    /// Show the panel window
    func show() {
        let panel = CapturePanelNSPanel(
            contentRect: NSRect(
                x: item.windowFrame.origin.x,
                y: item.windowFrame.origin.y,
                width: item.displaySize.width,
                height: item.displaySize.height
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = item.alwaysOnTop ? .floating : .normal
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = item.visibleOnAllDesktops
            ? [.canJoinAllSpaces, .fullScreenAuxiliary]
            : [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.alphaValue = item.opacity
        
        // Prevent app from terminating when this panel closes
        panel.isReleasedWhenClosed = false
        
        // Create SwiftUI view
        let view = CapturePanelView(
            item: item,
            onClose: { [weak self] in
                self?.close()
            },
            onScaleChange: { [weak self] _ in
                self?.updateWindowSize()
            },
            onOpacityChange: { [weak self] opacity in
                self?.window?.alphaValue = opacity
            }
        )
        
        let hosting = CapturePanelHostingView(rootView: view)
        hosting.frame = panel.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        hosting.onRightClick = { [weak panel, weak self] event in
            guard let panel = panel, let self = self else { return }
            let menu = NSMenu()

            let allDesktopsItem = NSMenuItem(
                title: "Show on All Desktops",
                action: #selector(panel.toggleVisibleOnAllDesktopsAction),
                keyEquivalent: ""
            )
            allDesktopsItem.target = panel
            allDesktopsItem.state = self.item.visibleOnAllDesktops ? .on : .off
            menu.addItem(allDesktopsItem)

            menu.addItem(.separator())

            let saveItem = NSMenuItem(title: "Save Image...", action: #selector(panel.saveImageAction), keyEquivalent: "")
            saveItem.target = panel
            menu.addItem(saveItem)
            NSMenu.popUpContextMenu(menu, with: event, for: hosting)
        }
        
        panel.contentView = hosting
        panel.shouldCloseHandler = { [weak self] in
            NSLog("[CapturePanelNSPanel] shouldClose called")
            self?.close()
        }
        
        // Set up scroll wheel zoom
        panel.onScrollWheel = { [weak self] delta in
            guard let self = self else { return }
            let scaleDelta = delta * 0.05
            self.item.adjustScale(by: scaleDelta)
            self.updateWindowSize()
        }

        // Set up Cmd+scroll wheel opacity (5% steps)
        panel.onScrollWheelOpacity = { [weak self] delta in
            guard let self = self else { return }
            let opacityDelta: CGFloat = delta > 0 ? 0.05 : -0.05
            self.item.adjustOpacity(by: opacityDelta)
        }
        
        // Set up right-click save
        panel.onSaveImage = { [weak self] in
            self?.saveImage()
        }

        // Set up toggle visible on all desktops
        panel.onToggleVisibleOnAllDesktops = { [weak self] in
            guard let self = self else { return }
            self.item.visibleOnAllDesktops.toggle()
        }
        
        self.window = panel
        self.hostingView = hosting
        
        // Observe item changes
        setupObservers()
        
        panel.makeKeyAndOrderFront(nil)
    }
    
    /// Close the panel window
    func close() {
        guard !isClosed else {
            NSLog("[CapturePanelWindowController] Already closed, ignoring")
            return
        }
        isClosed = true
        
        NSLog("[CapturePanelWindowController] Closing panel")
        cancellables.removeAll()
        window?.orderOut(nil)
        window = nil
        hostingView = nil
        onClose?()
    }
    
    /// Update window size based on item scale
    private func updateWindowSize() {
        guard let window = window else { return }
        
        let newSize = item.displaySize
        var frame = window.frame
        
        // Keep center position
        let centerX = frame.midX
        let centerY = frame.midY
        
        frame.size = newSize
        frame.origin.x = centerX - newSize.width / 2
        frame.origin.y = centerY - newSize.height / 2
        
        window.setFrame(frame, display: true, animate: false)
    }
    
    /// Save the captured image to a file
    private func saveImage() {
        NSLog("[CapturePanelWindowController] saveImage called")
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true
        
        // Generate default filename with timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: item.capturedAt)
        savePanel.nameFieldStringValue = "StickShot_\(timestamp).png"
        
        // Use beginSheetModal if we have a window, otherwise use begin
        if let window = self.window {
            NSLog("[CapturePanelWindowController] Showing save panel as sheet")
            savePanel.beginSheetModal(for: window) { [weak self] response in
                self?.handleSaveResponse(response: response, url: savePanel.url)
            }
        } else {
            NSLog("[CapturePanelWindowController] Showing save panel with begin")
            savePanel.begin { [weak self] response in
                self?.handleSaveResponse(response: response, url: savePanel.url)
            }
        }
    }
    
    private func handleSaveResponse(response: NSApplication.ModalResponse, url: URL?) {
        NSLog("[CapturePanelWindowController] Save panel response: \(response.rawValue)")
        
        guard response == .OK, let url = url else {
            NSLog("[CapturePanelWindowController] Save cancelled or no URL")
            return
        }
        
        // Convert NSImage to PNG data
        guard let tiffData = item.image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            NSLog("[CapturePanelWindowController] Failed to convert image to PNG")
            return
        }
        
        do {
            try pngData.write(to: url)
            NSLog("[CapturePanelWindowController] Image saved to \(url.path)")
        } catch {
            NSLog("[CapturePanelWindowController] Failed to save image: \(error)")
        }
    }
    
    private func setupObservers() {
        // Observe opacity changes
        item.$opacity
            .sink { [weak self] opacity in
                self?.window?.alphaValue = opacity
            }
            .store(in: &cancellables)
        
        // Observe alwaysOnTop changes
        item.$alwaysOnTop
            .sink { [weak self] alwaysOnTop in
                self?.window?.level = alwaysOnTop ? .floating : .normal
            }
            .store(in: &cancellables)
        
        // Observe visibleOnAllDesktops changes
        item.$visibleOnAllDesktops
            .sink { [weak self] visible in
                self?.window?.collectionBehavior = visible
                    ? [.canJoinAllSpaces, .fullScreenAuxiliary]
                    : [.moveToActiveSpace, .fullScreenAuxiliary]
            }
            .store(in: &cancellables)

        // Observe scale changes
        item.$scale
            .sink { [weak self] _ in
                self?.updateWindowSize()
            }
            .store(in: &cancellables)
    }
}

/// Custom NSPanel for capture display
class CapturePanelNSPanel: NSPanel {
    var shouldCloseHandler: (() -> Void)?
    var onScrollWheel: ((CGFloat) -> Void)?
    var onScrollWheelOpacity: ((CGFloat) -> Void)?
    var onSaveImage: (() -> Void)?
    var onToggleVisibleOnAllDesktops: (() -> Void)?
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    override func scrollWheel(with event: NSEvent) {
        // Ignore momentum scroll events - only respond to actual user scrolling
        if event.momentumPhase != [] && event.momentumPhase != .began {
            return
        }
        
        let delta = event.deltaY
        guard abs(delta) > 0.1 else { return }

        if event.modifierFlags.contains(.command) {
            // Cmd+Scroll: opacity adjustment
            onScrollWheelOpacity?(delta)
        } else {
            // Scroll: zoom adjustment
            onScrollWheel?(delta)
        }
    }
    
    override func keyDown(with event: NSEvent) {
        // ESC or Delete to close
        if event.keyCode == 53 || event.keyCode == 51 {
            shouldCloseHandler?()
            return
        }
        super.keyDown(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        // Double-click to close
        if event.clickCount == 2 {
            shouldCloseHandler?()
            return
        }
        super.mouseDown(with: event)
    }
    
    @objc func saveImageAction() {
        NSLog("[CapturePanelNSPanel] saveImageAction called")
        onSaveImage?()
    }

    @objc func toggleVisibleOnAllDesktopsAction() {
        onToggleVisibleOnAllDesktops?()
    }
}

/// Custom NSHostingView that handles right-click events
class CapturePanelHostingView<Content: View>: NSHostingView<Content> {
    var onRightClick: ((NSEvent) -> Void)?
    
    override func rightMouseDown(with event: NSEvent) {
        NSLog("[CapturePanelHostingView] rightMouseDown")
        if let handler = onRightClick {
            handler(event)
        } else {
            super.rightMouseDown(with: event)
        }
    }
}

