# <img src="./assets/clippin-logo-flat.png" alt="ClipPin logo" width="36" /> ClipPin

[**English**](./README.md) | [简体中文](./README.zh-CN.md)

Minimal native macOS utility built with Swift + AppKit:

- Clipboard history (text + images)
- Pin any history item as floating always-on-top cards
- Capture text from a screen region, remove line breaks, and copy it locally
- Live Pin an application window, or crop its live captions into a floating card (macOS 14+)

## Download & Install

Download the app zip from [GitHub Releases](https://github.com/xiangtaowong/ClipPin/releases/latest), unzip it, and move `ClipPin.app` to `/Applications`. This release supports Apple Silicon Macs running macOS 13 or later.

When updating, quit ClipPin before replacing `/Applications/ClipPin.app`. Launch that copy, then allow it in `System Settings > Privacy & Security > Screen & System Audio Recording` for screenshots and text capture. Quit and reopen ClipPin after granting permission.

The app uses ad-hoc signing, so an update may require permission again. If the switch is on but capture is denied, remove the old ClipPin entry with `-`, add `/Applications/ClipPin.app` with `+`, enable it, and restart ClipPin.

## What's New in 1.2.4

- Live Pin application windows with live updates, cropping, pause/resume, and per-pin opacity (macOS 14+).
- Content starts at the original window's size, including across displays with different pixel densities.
- Freely resize any edge or corner; drag the image or scroll to pan, and Command-drag to move the pin.
- Recover from lost window-picker callbacks and keep clipboard previews visible on macOS 27.
- Existing screenshots, on-device OCR, clipboard history, and text/image pins remain available.

See [CHANGELOG.md](./CHANGELOG.md) for release history.

## MVP Features

- Menubar app (accessory mode, no dock icon)
- Global hotkey: `Cmd+Shift+V` to open history dropdown
- Global quick paste hotkey: default `Option+Shift+C` to open history near cursor
- Global screenshot hotkey: default `F1` for region capture to clipboard
- Global text capture hotkey: default `Option+Shift+T` for region OCR to clipboard with line breaks removed
- Clipboard monitoring for plain text and images
- Consecutive dedupe + bounded history (100 items)
- Local persistence across restarts
- Configurable storage location for history and image files
- Optional launch at login
- Searchable status-bar dropdown history
- Pin-to-front for text and image snapshots
- Multiple pinned cards at once

## Controls

### Keyboard Shortcuts

| Action | Default shortcut | Example custom shortcut |
| --- | --- | --- |
| Region screenshot to clipboard | `F1` | `Cmd+1` |
| Open history near the mouse cursor (Quick Paste) | `Option+Shift+C` | `Cmd+2` |
| Region text capture, remove line breaks, copy | `Option+Shift+T` | `Cmd+3` |
| Open menubar history | `Cmd+Shift+V` | Fixed |

Your saved shortcuts are preserved when updating. The `Cmd+1/2/3` examples are not defaults: set them through `Preferences > Screenshot / Quick Paste / Text Capture Hotkey > Set Manually...`. `Current` shows the saved combination. Choose shortcuts that do not conflict with the apps you use.

### Copy, Pin & Recognize Text

1. **Screenshot:** press the Screenshot hotkey, drag to select a region, then use `Cmd+V` to paste the image.
2. **Text capture:** press the Text Capture hotkey, select a text region, wait for `Text copied`, then use `Cmd+V` to paste the single-line text. Press `Esc` to cancel selection.
3. **Pin:** open history using Quick Paste or the menubar icon, hold `Option`, and left-click a text or image item to keep it floating above other windows. OCR text can be pinned too.
4. **Opacity:** use `Default Opacity` in the menubar dropdown before making a pin. It applies to newly created pins; existing pins keep their opacity.

### Other Controls

- Menubar icon click: open clipboard dropdown menu
- Global quick paste: `Option` + `Shift` + `C` opens history menu near cursor
- Quick paste hotkey: configure in `Preferences > Quick Paste Hotkey`, supports manual key capture
- Click history item: copy back to clipboard (menu closes)
- `Option` + click history item: pin to front
- `Shift` + `Option` + click history item: delete from history
- Screenshot hotkey: configure in `Preferences > Screenshot Hotkey`, supports manual key capture (default `F1`)
- Text capture: press `Option+Shift+T`, select a region, and paste the recognized text with `Cmd+V`
- Text capture hotkey: configure in `Preferences > Text Capture Hotkey` using `Current` and `Set Manually...`
- Text capture joins Chinese lines directly and adds spaces between English lines; recognized text enters history and can also be pinned
- Storage location: configure in `Preferences > Storage Location`
- Launch at login: toggle in `Preferences`
- `Clear History`: clears all entries with confirmation

### Live Pin (macOS 14+)

1. Open the ClipPin menubar dropdown and choose `Live Pin…`.
2. Use the system picker to choose a single application window. Its live content appears in a floating pin.
3. Hold `Option` and drag across the pin to keep a region, such as live captions. Alternatively, right-click and choose `Crop Region…`, then drag to select. Press `Esc` to cancel and preserve the previous crop.
4. Drag any edge or corner to freely resize the viewport; drag the image or scroll to pan. Hold `Command` and drag to move the pin. Live Pins start fully opaque for readable text and retain the existing shadow preference. Adjust transparency per pin through the right-click `Opacity` menu.
5. Right-click for `Actual Size (100%)`, `Show Whole Window`, `Pause Live Pin` / `Resume Live Pin`, or `Close Live Pin`.

Live Pin matches the original window's size in screen points, so text keeps the same size even when the source and pin use displays with different pixel densities. Resizing the floating window changes the visible area without changing the content scale; drag the image or scroll to see content outside the viewport. `Actual Size (100%)` resets the view and expands it to the original window size, within the screen's available space. Capture updates to native resolution when the source changes size, keeping the last clear frame while resized capture catches up. Large windows are never silently downscaled; a capture limit or failure is reported by ScreenCaptureKit.

The source window can be covered or moved to another display. Keep it open and unminimized: minimized or unavailable windows stop updating, and restoring them normally resumes capture. If the source closes or capture fails, the pin shows a status message; close it and choose the source again when needed. Crops follow a proportional area of the source, so changes to the source layout can move text out of the selected region.

Live Pin uses ScreenCaptureKit and the system content picker. It only displays the selected window locally, with no audio capture, OCR, clipboard changes, saved frames, or uploads. `Pause` stops the capture stream, and closing a pin releases it. Multiple Live Pins may coexist. Live Pins are not restored after quitting. This entry is disabled on macOS 13; clipboard pins, screenshots, and OCR remain available.

Pinned cards:

- Content-only window (no extra toolbar buttons)
- Drag to move
- Resize
- Right-click pinned content and choose `Delete Pin` to close/remove

Pinned appearance settings (in dropdown menu):

- `Window Shadow` toggle
- `Default Opacity` for new clipboard pins; Live Pins have their own opacity menu

## Build & Run

Requirements:

- macOS 13+
- Xcode 15+ (or Swift 5.10+ toolchain)

Build:

```bash
swift build
```

Run OCR, clipboard, and Live Pin crop-geometry tests with Swift 6+ on macOS 14+ (Swift Testing):

```bash
swift test --disable-xctest
```

Optimized release build (smaller binary):

```bash
./scripts/build_optimized_release.sh
```

Build a publish-ready macOS `.app` (slimmed) + GitHub Release `.zip` + checksum:

```bash
./scripts/build_release_app.sh
```

Optional version:

```bash
./scripts/build_release_app.sh 1.1.0
```

Run:

```bash
swift run
```

## Data Storage

By default, history is stored at:

- `~/Library/Application Support/ClipPin/history.json`
- `~/Library/Application Support/ClipPin/images/`

You can change this in the dropdown menu (`Storage Location`).

## Notes

- Pinned windows are snapshot-based; clipboard changes later do not mutate existing pinned cards.
- Pinned windows are not restored across app relaunch in MVP.
- Screenshot hotkey uses system `screencapture -i -c` (interactive region capture to clipboard).
- Text capture uses on-device Apple Vision OCR with Chinese and English recognition. Screen Recording permission is required, just as for screenshots.
- Text capture deletes its temporary image and copies only the recognized text. Cancelling or finding no text leaves the clipboard unchanged.
- Text capture flattens text to one line; select a single paragraph or column for best results. Table and code formatting is not preserved.
- Launch at login is implemented via `~/Library/LaunchAgents/com.clippin.autostart.plist`.
- `build_release_app.sh` creates `release/ClipPin.app`, `release/ClipPin-<version>-macOS.zip`, and `.sha256`.

## Future Ideas (Post-MVP)

- Configurable history limit and hotkey
- Optional click-through mode for pinned cards
- Optional compact/expanded history row styles
- Built-in screenshot entry flow feeding the same snapshot pipeline
