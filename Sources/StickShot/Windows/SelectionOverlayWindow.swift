import AppKit

/// Controller for the selection overlay window
final class SelectionOverlayWindowController {
    private var windows: [SelectionOverlayNSWindow] = []
    
    var onSelectionComplete: ((CGRect, NSScreen) -> Void)?
    var onCancel: (() -> Void)?
    
    /// Show selection overlay on all screens
    func show() {
        close()
        
        NSLog("[SelectionOverlay] Showing overlays for \(NSScreen.screens.count) screens")
        
        // Create overlay for each screen
        for (index, screen) in NSScreen.screens.enumerated() {
            NSLog("[SelectionOverlay] Screen \(index): frame=\(screen.frame)")
            
            let window = SelectionOverlayNSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            
            window.associatedScreen = screen
            window.onSelectionComplete = { [weak self, weak window] rect in
                guard let self = self, let window = window, let screen = window.associatedScreen else { return }
                
                // Convert from window coordinates to screen coordinates
                let screenFrame = screen.frame
                let screenRect = CGRect(
                    x: rect.origin.x + screenFrame.origin.x,
                    y: screenFrame.origin.y + screenFrame.height - rect.origin.y - rect.height,
                    width: rect.width,
                    height: rect.height
                )
                
                NSLog("[SelectionOverlay] Converted rect \(rect) to screen rect \(screenRect) for screen at \(screenFrame)")
                self.onSelectionComplete?(screenRect, screen)
                self.close()
            }
            window.onCancel = { [weak self] in
                self?.onCancel?()
                self?.close()
            }
            
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = NSColor.black.withAlphaComponent(0.3)
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            
            // Position window at screen origin
            window.setFrame(screen.frame, display: true)
            
            // Create view with frame starting at (0,0)
            let viewFrame = NSRect(origin: .zero, size: screen.frame.size)
            let overlayView = SelectionOverlayNSView(frame: viewFrame)
            window.contentView = overlayView
            window.overlayView = overlayView
            
            NSLog("[SelectionOverlay] Created window at \(window.frame) with view frame \(viewFrame)")
            
            windows.append(window)
        }
        
        // Show all windows
        for window in windows {
            window.makeKeyAndOrderFront(nil)
        }
        
        // Make sure the app is active
        NSApp.activate(ignoringOtherApps: true)
        
        // Make the first window key
        if let firstWindow = windows.first {
            firstWindow.makeKey()
            if let view = firstWindow.overlayView {
                firstWindow.makeFirstResponder(view)
            }
        }
        
        // Force activation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
            self.windows.first?.makeKey()
        }
    }
    
    /// Close all overlay windows
    func close() {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
    }
}

/// Custom NSWindow for selection overlay with mouse event handling
class SelectionOverlayNSWindow: NSWindow {
    var associatedScreen: NSScreen?
    var overlayView: SelectionOverlayNSView?
    var onSelectionComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?
    
    private var isDragging = false
    private var startPoint: NSPoint = .zero
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            onCancel?()
            return
        }
        super.keyDown(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        print("[SelectionOverlay] mouseDown at: \(event.locationInWindow)")
        isDragging = true
        startPoint = event.locationInWindow
        overlayView?.startSelection(at: startPoint)
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        print("[SelectionOverlay] mouseDragged to: \(event.locationInWindow)")
        overlayView?.updateSelection(from: startPoint, to: event.locationInWindow)
    }
    
    override func mouseUp(with event: NSEvent) {
        guard isDragging else {
            NSLog("[SelectionOverlay] mouseUp but not dragging")
            return
        }
        isDragging = false
        
        overlayView?.updateSelection(from: startPoint, to: event.locationInWindow)
        
        if let rect = overlayView?.selectionRect, rect.width > 5, rect.height > 5 {
            NSLog("[SelectionOverlay] Selection complete, rect: \(rect)")
            onSelectionComplete?(rect)
        } else {
            NSLog("[SelectionOverlay] Selection too small or cancelled")
            onCancel?()
        }
    }
}

/// Custom NSView for drawing selection overlay
class SelectionOverlayNSView: NSView {
    var selectionRect: CGRect?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        NSLog("[SelectionOverlayNSView] becomeFirstResponder")
        return true
    }
    
    // Accept first mouse event without needing to click to focus
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    func startSelection(at point: NSPoint) {
        selectionRect = CGRect(origin: point, size: .zero)
        setNeedsDisplay(bounds)
    }
    
    func updateSelection(from start: NSPoint, to end: NSPoint) {
        selectionRect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        setNeedsDisplay(bounds)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let rect = selectionRect, rect.width > 0, rect.height > 0 else {
            // Draw instructions
            drawInstructions()
            return
        }
        
        // Clear selection area (make it transparent)
        if let context = NSGraphicsContext.current?.cgContext {
            context.setBlendMode(.copy)
            context.setFillColor(NSColor.clear.cgColor)
            context.fill(rect)
            context.setBlendMode(.normal)
        }
        
        // Draw white border around selection
        NSColor.white.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 2
        path.stroke()
        
        // Draw size label
        if rect.width > 60 && rect.height > 30 {
            let label = "\(Int(rect.width)) × \(Int(rect.height))"
            let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.white
            ]
            
            let size = (label as NSString).size(withAttributes: attrs)
            let labelX = rect.midX - size.width / 2
            let labelY = max(rect.minY - size.height - 10, 10)
            
            // Background
            let bgRect = NSRect(x: labelX - 6, y: labelY - 3, width: size.width + 12, height: size.height + 6)
            NSColor.black.withAlphaComponent(0.75).setFill()
            NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4).fill()
            
            // Text
            (label as NSString).draw(at: NSPoint(x: labelX, y: labelY), withAttributes: attrs)
        }
    }
    
    private func drawInstructions() {
        let text = "Drag to select"
        let font = NSFont.systemFont(ofSize: 18, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        
        let size = (text as NSString).size(withAttributes: attrs)
        let x = bounds.midX - size.width / 2
        let y = bounds.midY - size.height / 2
        
        // Background
        let bgRect = NSRect(x: x - 16, y: y - 10, width: size.width + 32, height: size.height + 20)
        NSColor.black.withAlphaComponent(0.6).setFill()
        NSBezierPath(roundedRect: bgRect, xRadius: 8, yRadius: 8).fill()
        
        // Text
        (text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
    }
}
