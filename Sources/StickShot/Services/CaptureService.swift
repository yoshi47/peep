import Foundation
import ScreenCaptureKit
import AppKit
import CoreGraphics

/// Service for capturing screen regions using ScreenCaptureKit
final class CaptureService: NSObject {
    static let shared = CaptureService()
    
    enum CaptureError: Error, LocalizedError {
        case noPermission
        case noDisplayFound
        case captureFailedToStart
        case noFrameCaptured
        case imageConversionFailed
        case timeout
        
        var errorDescription: String? {
            switch self {
            case .noPermission:
                return "Screen recording permission is required."
            case .noDisplayFound:
                return "No display found for the selected region."
            case .captureFailedToStart:
                return "Failed to start screen capture."
            case .noFrameCaptured:
                return "No frame was captured."
            case .imageConversionFailed:
                return "Failed to convert captured frame to image."
            case .timeout:
                return "Capture timed out."
            }
        }
    }
    
    private override init() {
        super.init()
    }
    
    /// Check if screen recording permission is granted
    func checkPermission() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            print("[CaptureService] Permission check failed: \(error)")
            return false
        }
    }
    
    /// Capture a region of the screen
    func captureRegion(rect: CGRect, screen: NSScreen) async throws -> NSImage {
        print("[CaptureService] captureRegion called with rect: \(rect)")
        
        guard await checkPermission() else {
            print("[CaptureService] No permission")
            throw CaptureError.noPermission
        }
        
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        print("[CaptureService] Found \(content.displays.count) displays")
        
        guard let display = findDisplay(for: screen, in: content.displays) else {
            print("[CaptureService] Display not found")
            throw CaptureError.noDisplayFound
        }
        
        print("[CaptureService] Using display: \(display.displayID)")
        
        // Always capture at 2x resolution minimum for better quality on non-Retina displays
        let scaleFactor = max(screen.backingScaleFactor, 2.0)
        let screenFrame = screen.frame
        
        // Convert from global screen coordinates to display-local coordinates
        let localRect = CGRect(
            x: rect.origin.x - screenFrame.origin.x,
            y: rect.origin.y - screenFrame.origin.y,
            width: rect.width,
            height: rect.height
        )
        
        print("[CaptureService] Local rect: \(localRect), scale: \(scaleFactor)")
        
        let config = SCStreamConfiguration()
        config.width = Int(rect.width * scaleFactor)
        config.height = Int(rect.height * scaleFactor)
        config.sourceRect = localRect
        config.scalesToFit = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB
        config.showsCursor = false
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1 FPS is enough
        
        print("[CaptureService] Config: \(config.width)x\(config.height)")
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        let image = try await captureSingleFrame(filter: filter, config: config, scaleFactor: scaleFactor)
        print("[CaptureService] Capture successful")
        return image
    }
    
    private func findDisplay(for screen: NSScreen, in displays: [SCDisplay]) -> SCDisplay? {
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return nil
        }
        return displays.first { $0.displayID == screenNumber }
    }
    
    private func captureSingleFrame(filter: SCContentFilter, config: SCStreamConfiguration, scaleFactor: CGFloat) async throws -> NSImage {
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<NSImage, Error>) in
            var didResume = false
            
            let streamOutput = SingleFrameStreamOutput(scaleFactor: scaleFactor) { result in
                NSLog("[CaptureService] Frame callback received")
                guard !didResume else {
                    NSLog("[CaptureService] Already resumed, ignoring")
                    return
                }
                didResume = true
                
                Task {
                    try? await stream.stopCapture()
                    NSLog("[CaptureService] Stream stopped")
                }
                
                switch result {
                case .success(let image):
                    NSLog("[CaptureService] Resuming with image")
                    continuation.resume(returning: image)
                case .failure(let error):
                    NSLog("[CaptureService] Resuming with error: \(error)")
                    continuation.resume(throwing: error)
                }
            }
            
            Task {
                do {
                    try stream.addStreamOutput(streamOutput, type: .screen, sampleHandlerQueue: .main)
                    NSLog("[CaptureService] Stream output added")
                    
                    NSLog("[CaptureService] Starting capture...")
                    try await stream.startCapture()
                    NSLog("[CaptureService] Capture started successfully")
                    
                    // Set a timeout
                    try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds timeout
                    if !didResume {
                        NSLog("[CaptureService] Timeout - no frame received")
                        didResume = true
                        continuation.resume(throwing: CaptureError.timeout)
                    }
                } catch {
                    NSLog("[CaptureService] Failed: \(error)")
                    if !didResume {
                        didResume = true
                        continuation.resume(throwing: CaptureError.captureFailedToStart)
                    }
                }
            }
        }
    }
}

/// Helper class to capture a single frame from SCStream
private class SingleFrameStreamOutput: NSObject, SCStreamOutput {
    private var completion: ((Result<NSImage, CaptureService.CaptureError>) -> Void)?
    private var hasCaptured = false
    private let scaleFactor: CGFloat
    
    init(scaleFactor: CGFloat, completion: @escaping (Result<NSImage, CaptureService.CaptureError>) -> Void) {
        self.scaleFactor = scaleFactor
        self.completion = completion
        super.init()
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard !hasCaptured, type == .screen else { return }
        
        print("[SingleFrameStreamOutput] Received frame")
        hasCaptured = true
        
        if let image = createImage(from: sampleBuffer) {
            print("[SingleFrameStreamOutput] Image created: \(image.size)")
            completion?(.success(image))
        } else {
            print("[SingleFrameStreamOutput] Image conversion failed")
            completion?(.failure(.imageConversionFailed))
        }
        completion = nil
    }
    
    private func createImage(from sampleBuffer: CMSampleBuffer) -> NSImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("[SingleFrameStreamOutput] No pixel buffer")
            return nil
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("[SingleFrameStreamOutput] CGImage creation failed")
            return nil
        }
        
        let pointSize = CGSize(
            width: CGFloat(cgImage.width) / scaleFactor,
            height: CGFloat(cgImage.height) / scaleFactor
        )
        
        return NSImage(cgImage: cgImage, size: pointSize)
    }
}
