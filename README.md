# StickShot

macOS用のスクリーンキャプチャアプリ。画面の任意範囲をキャプチャし、常駐ウィンドウとして表示できます。

## 機能

- **範囲選択キャプチャ**: ホットキー（⌥⌘P）で範囲選択モードを起動し、ドラッグで範囲を選択
- **貼り付け表示**: キャプチャ画像を独立したウィンドウとして表示
- **複数枚同時表示**: 複数のキャプチャを同時に画面上に保持
- **拡大・縮小**: スクロールホイールまたはピンチジェスチャーでズーム（25%〜400%）
- **透明度変更**: スライダーで透明度を調整（20%〜100%）

## 動作環境

- macOS 13.0以上
- 画面収録の権限が必要

## ビルド方法

### Swift Package Manager

```bash
cd stickshot
swift build
```

### Xcode

1. `Package.swift`をXcodeで開く
2. ビルドターゲットを選択してビルド

## 使い方

1. アプリを起動（メニューバーにアイコンが表示されます）
2. `⌥⌘P`（Option + Command + P）を押すか、メニューバーアイコンから「Capture Region」を選択
3. ドラッグして範囲を選択（ESCでキャンセル）
4. キャプチャ画像がウィンドウとして表示されます

### パネル操作

- **移動**: ウィンドウをドラッグ
- **拡大・縮小**: スクロールホイールまたはピンチジェスチャー
- **透明度変更**: ホバー時に表示されるスライダーで調整
- **閉じる**: ダブルクリック、ESCキー、または×ボタン

## プロジェクト構成

```
Sources/StickShot/
├── StickShotApp.swift           # アプリエントリーポイント
├── AppCoordinator.swift         # 全体連携
├── Models/
│   └── CaptureItem.swift        # キャプチャデータモデル
├── Services/
│   ├── CaptureService.swift     # ScreenCaptureKit連携
│   └── HotkeyService.swift      # グローバルホットキー
├── Views/
│   ├── SelectionOverlayView.swift    # 範囲選択UI
│   └── CapturePanelView.swift        # パネルUI
└── Windows/
    ├── SelectionOverlayWindow.swift  # 範囲選択Window
    ├── CapturePanelWindow.swift      # パネルWindow
    └── PanelManager.swift            # パネル管理
```

## 権限

初回起動時に「画面収録」の権限を求められます。システム設定 > プライバシーとセキュリティ > 画面収録 で許可してください。

## ライセンス

MIT License
