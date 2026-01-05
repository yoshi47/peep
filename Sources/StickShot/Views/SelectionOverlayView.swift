import SwiftUI
import AppKit

/// SwiftUI view for the selection overlay
struct SelectionOverlayView: View {
    @ObservedObject var viewModel: SelectionOverlayViewModel
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.3)
                
                // Selection rectangle
                if let selection = viewModel.selectionRect {
                    // Clear area for selection (cut out from overlay)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: selection.width, height: selection.height)
                        .position(
                            x: selection.midX,
                            y: selection.midY
                        )
                        .background(
                            Rectangle()
                                .stroke(Color.white, lineWidth: 2)
                                .shadow(color: .black.opacity(0.5), radius: 2)
                        )
                    
                    // Dimension label
                    if selection.width > 50 && selection.height > 20 {
                        Text("\(Int(selection.width)) × \(Int(selection.height))")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                            .position(
                                x: selection.midX,
                                y: min(selection.maxY + 20, geometry.size.height - 20)
                            )
                    }
                }
                
                // Instructions
                if viewModel.selectionRect == nil {
                    VStack(spacing: 8) {
                        Text("Drag to select a region")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        Text("Press ESC to cancel")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// ViewModel for selection overlay state
final class SelectionOverlayViewModel: ObservableObject {
    @Published var selectionRect: CGRect?
    private var startPoint: CGPoint?
    
    var onSelectionComplete: ((CGRect, NSScreen) -> Void)?
    var onCancel: (() -> Void)?
    
    func startSelection(at point: CGPoint) {
        startPoint = point
        selectionRect = CGRect(origin: point, size: .zero)
    }
    
    func updateSelection(to point: CGPoint) {
        guard let start = startPoint else { return }
        
        let rect = CGRect(
            x: min(start.x, point.x),
            y: min(start.y, point.y),
            width: abs(point.x - start.x),
            height: abs(point.y - start.y)
        )
        
        selectionRect = rect
    }
    
    func endSelection(at point: CGPoint, screen: NSScreen) {
        updateSelection(to: point)
        
        guard let rect = selectionRect, rect.width > 5, rect.height > 5 else {
            cancel()
            return
        }
        
        onSelectionComplete?(rect, screen)
    }
    
    func cancel() {
        selectionRect = nil
        startPoint = nil
        onCancel?()
    }
    
    func reset() {
        selectionRect = nil
        startPoint = nil
    }
}

