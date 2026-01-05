import AppKit
import SwiftUI
import Combine

/// Controller for a single capture panel window
final class CapturePanelWindowController {
    let item: CaptureItem
    private var window: NSPanel?
    private var hostingView: NSHostingView<CapturePanelView>?
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
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
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
        
        let hosting = NSHostingView(rootView: view)
        hosting.frame = panel.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        
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

        // Set up Cmd+scroll wheel opacity
        panel.onScrollWheelOpacity = { [weak self] delta in
            guard let self = self else { return }
            let opacityDelta = delta * 0.05
            self.item.adjustOpacity(by: opacityDelta)
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
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    override func scrollWheel(with event: NSEvent) {
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
}

