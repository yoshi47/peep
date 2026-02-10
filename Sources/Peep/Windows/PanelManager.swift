import Foundation
import AppKit

/// Manager for multiple capture panel windows
final class PanelManager {
    static let shared = PanelManager()
    
    private var panels: [UUID: CapturePanelWindowController] = [:]
    
    private init() {}
    
    /// Create and show a new panel for the given capture item
    /// - Parameter item: The capture item to display
    func createPanel(for item: CaptureItem) {
        let controller = CapturePanelWindowController(item: item)
        
        controller.onClose = { [weak self] in
            self?.removePanel(id: item.id)
        }
        
        panels[item.id] = controller
        controller.show()
    }
    
    /// Remove a panel by its ID
    /// - Parameter id: The ID of the capture item
    func removePanel(id: UUID) {
        panels[id]?.close()
        panels.removeValue(forKey: id)
    }
    
    /// Close all panels
    func closeAllPanels() {
        for (_, controller) in panels {
            controller.close()
        }
        panels.removeAll()
    }
    
    /// Get the number of active panels
    var panelCount: Int {
        panels.count
    }
    
    /// Get all active capture items
    var activeItems: [CaptureItem] {
        panels.values.map { $0.item }
    }
    
    /// Check if a panel exists for the given ID
    func hasPanel(id: UUID) -> Bool {
        panels[id] != nil
    }
}

