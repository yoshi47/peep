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
        hotkeyService.registerHotkey { [weak self] in
            DispatchQueue.main.async {
                self?.startCapture()
            }
        }

        Task {
            let hasPermission = await CaptureService.shared.checkPermission()
            if !hasPermission {
                await MainActor.run { self.showPermissionAlert() }
            }
        }
    }

    /// Start the capture process (show selection overlay)
    func startCapture() {
        guard !isCapturing else { return }
        isCapturing = true

        let controller = SelectionOverlayWindowController()

        controller.onSelectionComplete = { [weak self] rect, screen in
            self?.performCapture(rect: rect, screen: screen)
        }

        controller.onCancel = { [weak self] in
            self?.cancelCapture()
        }

        selectionOverlayController = controller
        controller.show()
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

    // MARK: - Private

    private func performCapture(rect: CGRect, screen: NSScreen) {
        selectionOverlayController?.close()
        selectionOverlayController = nil

        // Wait for overlay to disappear before capturing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Task {
                do {
                    let image = try await CaptureService.shared.captureRegion(rect: rect, screen: screen)

                    await MainActor.run {
                        let item = CaptureItem(
                            image: image,
                            originalSize: CGSize(width: rect.width, height: rect.height),
                            initialFrame: rect
                        )
                        PanelManager.shared.createPanel(for: item)
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
    }

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

    private func showErrorAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Capture Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
