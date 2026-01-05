import AppKit

// MARK: - Constants

private enum SelectionOverlayConstants {
    static let overlayOpacity: CGFloat = 0.3
    static let minimumSelectionSize: CGFloat = 5.0
    static let borderWidth: CGFloat = 2.0
    static let borderColor: NSColor = .white

    enum SizeLabel {
        static let minWidth: CGFloat = 60.0
        static let minHeight: CGFloat = 30.0
        static let fontSize: CGFloat = 11.0
        static let fontWeight: NSFont.Weight = .medium
        static let horizontalPadding: CGFloat = 6.0
        static let verticalPadding: CGFloat = 3.0
        static let backgroundOpacity: CGFloat = 0.75
        static let cornerRadius: CGFloat = 4.0
        static let offset: CGFloat = 10.0
        static let minEdgeInset: CGFloat = 10.0
    }

    enum Instructions {
        static let text = "Drag to select"
        static let fontSize: CGFloat = 18.0
        static let fontWeight: NSFont.Weight = .medium
        static let horizontalPadding: CGFloat = 16.0
        static let verticalPadding: CGFloat = 10.0
        static let backgroundOpacity: CGFloat = 0.6
        static let cornerRadius: CGFloat = 8.0
    }
}

// MARK: - Controller

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
            window.backgroundColor = NSColor.black.withAlphaComponent(SelectionOverlayConstants.overlayOpacity)
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
        
        let minSize = SelectionOverlayConstants.minimumSelectionSize
        if let rect = overlayView?.selectionRect, rect.width > minSize, rect.height > minSize {
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
            drawInstructions()
            return
        }

        clearSelectionArea(rect)
        drawSelectionBorder(rect)
        drawSizeLabel(for: rect)
    }

    // MARK: - Drawing Helpers

    private func clearSelectionArea(_ rect: CGRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setBlendMode(.copy)
        context.setFillColor(NSColor.clear.cgColor)
        context.fill(rect)
        context.setBlendMode(.normal)
    }

    private func drawSelectionBorder(_ rect: CGRect) {
        SelectionOverlayConstants.borderColor.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = SelectionOverlayConstants.borderWidth
        path.stroke()
    }

    private func drawSizeLabel(for rect: CGRect) {
        typealias Config = SelectionOverlayConstants.SizeLabel

        guard rect.width > Config.minWidth, rect.height > Config.minHeight else { return }

        let label = "\(Int(rect.width)) × \(Int(rect.height))"
        let font = NSFont.monospacedSystemFont(ofSize: Config.fontSize, weight: Config.fontWeight)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]

        let size = (label as NSString).size(withAttributes: attrs)
        let labelX = rect.midX - size.width / 2
        let labelY = max(rect.minY - size.height - Config.offset, Config.minEdgeInset)

        let bgRect = NSRect(
            x: labelX - Config.horizontalPadding,
            y: labelY - Config.verticalPadding,
            width: size.width + Config.horizontalPadding * 2,
            height: size.height + Config.verticalPadding * 2
        )
        NSColor.black.withAlphaComponent(Config.backgroundOpacity).setFill()
        NSBezierPath(roundedRect: bgRect, xRadius: Config.cornerRadius, yRadius: Config.cornerRadius).fill()

        (label as NSString).draw(at: NSPoint(x: labelX, y: labelY), withAttributes: attrs)
    }

    private func drawInstructions() {
        typealias Config = SelectionOverlayConstants.Instructions

        let font = NSFont.systemFont(ofSize: Config.fontSize, weight: Config.fontWeight)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]

        let size = (Config.text as NSString).size(withAttributes: attrs)
        let x = bounds.midX - size.width / 2
        let y = bounds.midY - size.height / 2

        let bgRect = NSRect(
            x: x - Config.horizontalPadding,
            y: y - Config.verticalPadding,
            width: size.width + Config.horizontalPadding * 2,
            height: size.height + Config.verticalPadding * 2
        )
        NSColor.black.withAlphaComponent(Config.backgroundOpacity).setFill()
        NSBezierPath(roundedRect: bgRect, xRadius: Config.cornerRadius, yRadius: Config.cornerRadius).fill()

        (Config.text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
    }
}
