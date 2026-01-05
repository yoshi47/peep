import Foundation
import AppKit

/// Main coordinator for the application, orchestrating all services and windows
final class AppCoordinator {
    static let shared = AppCoordinator()
    
    private let hotkeyService = HotkeyService.shared
    
    private var selectionOverlayController: SelectionOverlayWindowController?
    private var isCapturing = false
    
    private init() {}
    
    /// Start the coordinator and register services
    func start() {
        // Register global hotkey
        hotkeyService.registerHotkey { [weak self] in
            DispatchQueue.main.async {
                self?.startCapture()
            }
        }
        
        // Check screen recording permission on startup
        Task {
            let hasPermission = await CaptureService.shared.checkPermission()
            if !hasPermission {
                await MainActor.run {
                    self.showPermissionAlert()
                }
            }
        }
    }
    
    /// Start the capture process (show selection overlay)
    func startCapture() {
        NSLog("[AppCoordinator] startCapture called")
        
        guard !isCapturing else {
            NSLog("[AppCoordinator] Already capturing")
            return
        }
        isCapturing = true
        
        let controller = SelectionOverlayWindowController()
        
        controller.onSelectionComplete = { [weak self] rect, screen in
            NSLog("[AppCoordinator] Selection complete callback: rect=\(rect)")
            self?.performCapture(rect: rect, screen: screen)
        }
        
        controller.onCancel = { [weak self] in
            NSLog("[AppCoordinator] Selection cancelled")
            self?.cancelCapture()
        }
        
        selectionOverlayController = controller
        controller.show()
        NSLog("[AppCoordinator] Overlay shown")
    }
    
    /// Cancel the current capture
    func cancelCapture() {
        selectionOverlayController?.close()
        selectionOverlayController = nil
        isCapturing = false
    }
    
    /// Close all capture panels
    func closeAllPanels() {
        PanelManager.shared.closeAllPanels()
    }
    
    /// Perform the actual capture
    private func performCapture(rect: CGRect, screen: NSScreen) {
        NSLog("[AppCoordinator] performCapture called with rect: \(rect)")
        
        // Close selection overlay
        selectionOverlayController?.close()
        selectionOverlayController = nil
        
        Task {
            do {
                NSLog("[AppCoordinator] Starting capture...")
                let image = try await CaptureService.shared.captureRegion(rect: rect, screen: screen)
                NSLog("[AppCoordinator] Capture successful, image size: \(image.size)")
                
                await MainActor.run {
                    // Create capture item
                    let item = CaptureItem(
                        image: image,
                        originalSize: CGSize(width: rect.width, height: rect.height),
                        initialFrame: rect
                    )
                    
                    NSLog("[AppCoordinator] Creating panel at frame: \(rect)")
                    // Show panel
                    PanelManager.shared.createPanel(for: item)
                    NSLog("[AppCoordinator] Panel created successfully. Panel count: \(PanelManager.shared.panelCount)")
                }
                
            } catch {
                NSLog("[AppCoordinator] Capture failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.showErrorAlert(error: error)
                }
            }
            
            await MainActor.run {
                self.isCapturing = false
            }
        }
    }
    
    /// Show permission alert
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "StickShot needs screen recording permission to capture screen regions. Please grant permission in System Settings > Privacy & Security > Screen Recording."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    /// Show error alert
    private func showErrorAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Capture Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
