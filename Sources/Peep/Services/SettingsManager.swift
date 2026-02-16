import Foundation
import AppKit

/// アプリケーション設定を管理するシングルトンクラス
final class SettingsManager {
    static let shared = SettingsManager()

    private let userDefaults = UserDefaults.standard

    // UserDefaultsのキー定義
    private enum Keys {
        static let autoCopyToClipboard = "autoCopyToClipboard"
    }

    private init() {
        // デフォルト値の登録
        registerDefaults()
    }

    /// デフォルト値を登録
    private func registerDefaults() {
        userDefaults.register(defaults: [
            Keys.autoCopyToClipboard: false  // デフォルトはオフ
        ])
    }

    /// 自動クリップボードコピーが有効かどうか
    var autoCopyToClipboard: Bool {
        get {
            userDefaults.bool(forKey: Keys.autoCopyToClipboard)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.autoCopyToClipboard)
        }
    }
}
