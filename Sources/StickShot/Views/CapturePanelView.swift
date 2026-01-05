import SwiftUI
import AppKit

/// SwiftUI view for displaying a captured image with controls
struct CapturePanelView: View {
    @ObservedObject var item: CaptureItem
    @State private var isHovering = false
    @State private var showControls = false
    
    var onClose: (() -> Void)?
    var onScaleChange: ((CGFloat) -> Void)?
    var onOpacityChange: ((CGFloat) -> Void)?
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main image
            Image(nsImage: item.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(
                    width: item.displaySize.width,
                    height: item.displaySize.height
                )
            
            // Controls overlay (shown on hover)
            if isHovering || showControls {
                controlsOverlay
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    let delta = (value - 1) * 0.1
                    item.adjustScale(by: delta)
                    onScaleChange?(item.scale)
                }
        )
    }
    
    private var controlsOverlay: some View {
        VStack(spacing: 0) {
            // Top bar with close button
            HStack {
                Spacer()
                
                Button(action: { onClose?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                }
                .buttonStyle(.plain)
                .padding(8)
            }
            
            Spacer()
            
            // Bottom controls
            VStack(spacing: 8) {
                // Scale slider
                HStack(spacing: 8) {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                    
                    Slider(
                        value: Binding(
                            get: { item.scale },
                            set: { newValue in
                                item.setScale(newValue)
                                onScaleChange?(newValue)
                            }
                        ),
                        in: CaptureItem.minScale...CaptureItem.maxScale
                    )
                    .frame(width: 100)
                    
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                    
                    Text("\(Int(item.scale * 100))%")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 40)
                }
                
                // Opacity slider
                HStack(spacing: 8) {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                    
                    Slider(
                        value: Binding(
                            get: { item.opacity },
                            set: { newValue in
                                item.setOpacity(newValue)
                                onOpacityChange?(newValue)
                            }
                        ),
                        in: CaptureItem.minOpacity...CaptureItem.maxOpacity
                    )
                    .frame(width: 100)
                    
                    Image(systemName: "circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                    
                    Text("\(Int(item.opacity * 100))%")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 40)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.7))
            )
            .padding(8)
        }
    }
}

/// View modifier for scroll wheel zoom
struct ScrollWheelZoomModifier: ViewModifier {
    @Binding var scale: CGFloat
    let minScale: CGFloat
    let maxScale: CGFloat
    var onScaleChange: ((CGFloat) -> Void)?
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: NSView.boundsDidChangeNotification)) { _ in
                // Handle scroll wheel events through NSView
            }
    }
}
