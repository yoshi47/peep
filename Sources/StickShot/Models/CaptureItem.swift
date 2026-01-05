import Foundation
import AppKit

/// Represents a captured screen region with its associated state
final class CaptureItem: Identifiable, ObservableObject {
    let id: UUID
    let image: NSImage
    let originalSize: CGSize
    let capturedAt: Date
    
    @Published var scale: CGFloat
    @Published var opacity: CGFloat
    @Published var alwaysOnTop: Bool
    @Published var clickThroughLocked: Bool
    @Published var windowFrame: CGRect
    
    /// Minimum scale factor for zoom
    static let minScale: CGFloat = 0.25
    /// Maximum scale factor for zoom
    static let maxScale: CGFloat = 4.0
    /// Minimum opacity value
    static let minOpacity: CGFloat = 0.2
    /// Maximum opacity value
    static let maxOpacity: CGFloat = 1.0
    
    init(
        image: NSImage,
        originalSize: CGSize,
        initialFrame: CGRect
    ) {
        self.id = UUID()
        self.image = image
        self.originalSize = originalSize
        self.capturedAt = Date()
        self.scale = 1.0
        self.opacity = 1.0
        self.alwaysOnTop = true
        self.clickThroughLocked = false
        self.windowFrame = initialFrame
    }
    
    /// Current display size based on scale
    var displaySize: CGSize {
        CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )
    }
    
    /// Adjust scale within valid bounds
    func adjustScale(by delta: CGFloat) {
        let newScale = max(Self.minScale, min(Self.maxScale, scale + delta))
        scale = newScale
    }
    
    /// Set scale within valid bounds
    func setScale(_ newScale: CGFloat) {
        scale = max(Self.minScale, min(Self.maxScale, newScale))
    }
    
    /// Adjust opacity within valid bounds
    func adjustOpacity(by delta: CGFloat) {
        let newOpacity = max(Self.minOpacity, min(Self.maxOpacity, opacity + delta))
        opacity = newOpacity
    }
    
    /// Set opacity within valid bounds
    func setOpacity(_ newOpacity: CGFloat) {
        opacity = max(Self.minOpacity, min(Self.maxOpacity, newOpacity))
    }
}



