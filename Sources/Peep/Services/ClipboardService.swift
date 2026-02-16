import Foundation
import AppKit

/// クリップボード操作を管理するサービスクラス
final class ClipboardService {
    static let shared = ClipboardService()

    private init() {}

    /// NSImageをクリップボードにコピー
    /// - Parameter image: コピーする画像
    /// - Returns: 成功した場合true、失敗した場合false
    @discardableResult
    func copyImage(_ image: NSImage) -> Bool {
        guard let tiffData = image.tiffRepresentation else {
            NSLog("[ClipboardService] Failed to get TIFF representation")
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let success = pasteboard.setData(tiffData, forType: .tiff)

        if success {
            NSLog("[ClipboardService] Image copied to clipboard")
        } else {
            NSLog("[ClipboardService] Failed to copy image to clipboard")
        }

        return success
    }
}
