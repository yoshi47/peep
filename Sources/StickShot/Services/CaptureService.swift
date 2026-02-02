import Foundation
import ScreenCaptureKit
import AppKit

/// Service for capturing screen regions using ScreenCaptureKit
final class CaptureService: NSObject {
    static let shared = CaptureService()

    enum CaptureError: Error, LocalizedError {
        case noPermission
        case noDisplayFound
        case imageConversionFailed
        case timeout

        var errorDescription: String? {
            switch self {
            case .noPermission:
                return "Screen recording permission is required."
            case .noDisplayFound:
                return "No display found for the selected region."
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

    /// Check if screen recording permission is granted via SCShareableContent.
    func checkPermission() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            NSLog("[CaptureService] Permission check failed: \(error)")
            return false
        }
    }

    /// Capture a region of the screen
    func captureRegion(rect: CGRect, screen: NSScreen) async throws -> NSImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = findDisplay(for: screen, in: content.displays) else {
            throw CaptureError.noDisplayFound
        }

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

        let config = SCStreamConfiguration()
        config.width = Int(rect.width * scaleFactor)
        config.height = Int(rect.height * scaleFactor)
        config.sourceRect = localRect
        config.scalesToFit = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB
        config.showsCursor = false
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let filter = SCContentFilter(display: display, excludingWindows: [])
        return try await captureSingleFrame(filter: filter, config: config, scaleFactor: scaleFactor)
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
                guard !didResume else { return }
                didResume = true

                Task { try? await stream.stopCapture() }

                switch result {
                case .success(let image):
                    continuation.resume(returning: image)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            Task {
                do {
                    try stream.addStreamOutput(streamOutput, type: .screen, sampleHandlerQueue: .main)
                    try await stream.startCapture()

                    // Timeout
                    try await Task.sleep(nanoseconds: 10_000_000_000)
                    if !didResume {
                        didResume = true
                        continuation.resume(throwing: CaptureError.timeout)
                    }
                } catch {
                    NSLog("[CaptureService] Stream failed: \(error.localizedDescription)")
                    if !didResume {
                        didResume = true
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}

/// Helper class to capture a single frame from SCStream
private class SingleFrameStreamOutput: NSObject, SCStreamOutput {
    private var completion: ((Result<NSImage, Error>) -> Void)?
    private var hasCaptured = false
    private let scaleFactor: CGFloat

    init(scaleFactor: CGFloat, completion: @escaping (Result<NSImage, Error>) -> Void) {
        self.scaleFactor = scaleFactor
        self.completion = completion
        super.init()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard !hasCaptured, type == .screen else { return }
        hasCaptured = true

        if let image = createImage(from: sampleBuffer) {
            completion?(.success(image))
        } else {
            completion?(.failure(CaptureService.CaptureError.imageConversionFailed))
        }
        completion = nil
    }

    private func createImage(from sampleBuffer: CMSampleBuffer) -> NSImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        let pointSize = CGSize(
            width: CGFloat(cgImage.width) / scaleFactor,
            height: CGFloat(cgImage.height) / scaleFactor
        )

        return NSImage(cgImage: cgImage, size: pointSize)
    }
}
