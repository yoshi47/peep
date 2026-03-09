<p align="center">
  <img src="assets/icon.png" alt="Peep" width="128">
</p>

<h1 align="center">Peep</h1>

<p align="center">
  A lightweight floating screen capture tool for macOS.<br>
  Capture any region of your screen and keep it as a floating panel — always on top, across all desktops.
</p>

## Features

- Region capture with global hotkey (⌥⌘P)
- Floating panels — always on top, visible on all desktops
- Zoom 25%–400% via scroll wheel, pinch, or buttons
- Opacity 20%–100% via ⌘+scroll or slider
- Auto copy to clipboard
- Save as PNG via right-click menu
- Multiple captures simultaneously
- Launch at login
- Multi-monitor support

## Installation

### Download

1. Go to [GitHub Releases](../../releases) and download the latest `.zip`
2. Unzip and move `Peep.app` to `/Applications`
3. Open the app — a menu bar icon will appear

### Requirements

- macOS 13.0+
- Screen Recording permission (see [Permissions](#permissions))

## Usage

1. Press **⌥⌘P** (or click the menu bar icon → **Capture Region**)
2. Drag to select a region (press **ESC** to cancel)
3. The captured area appears as a floating panel

### Panel Controls

- **Move** — drag the panel
- **Zoom** — scroll wheel or pinch gesture
- **Opacity** — ⌘+scroll or hover to reveal the slider
- **Close** — double-click, ESC, Delete, or the × button

## Keyboard Shortcuts & Controls

### Global

| Shortcut | Action |
|----------|--------|
| ⌥⌘P | Capture region |
| ⌘Q | Quit Peep |

### Panel

| Input | Action |
|-------|--------|
| Scroll wheel | Zoom in / out |
| Pinch gesture | Zoom in / out |
| ⌘ + Scroll wheel | Adjust opacity |
| Double-click | Close panel |
| ESC / Delete | Close panel |

### Right-Click Menu

| Item | Action |
|------|--------|
| Show on All Desktops | Toggle panel visibility across desktops |
| Copy to Clipboard | Copy the capture image |
| Save Image... | Save as PNG |

## Menu Bar Items

| Item | Description |
|------|-------------|
| Capture Region (⌥⌘P) | Start a new capture |
| Launch at Login | Toggle auto-start on login |
| Auto Copy to Clipboard | Toggle automatic clipboard copy after capture |
| Bring All to Front | Bring all capture panels to the front |
| Send All to Back | Send all capture panels behind other windows |
| Close All Captures | Close every open capture panel |
| Quit Peep (⌘Q) | Quit the application |

## Permissions

Peep requires **Screen Recording** permission to capture your screen.

On first launch, macOS will prompt you to grant access. If you need to enable it manually:

1. Open **System Settings** → **Privacy & Security** → **Screen Recording**
2. Enable **Peep**
3. Restart the app if needed

## License

MIT License
