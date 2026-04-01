# <img src="./assets/clippin-logo-flat.png" alt="ClipPin logo" width="36" /> ClipPin

[**English**](./README.md) | [简体中文](./README.zh-CN.md)

Minimal native macOS utility built with Swift + AppKit:

- Clipboard history (text + images)
- Pin any history item as floating always-on-top cards

## MVP Features

- Menubar app (accessory mode, no dock icon)
- Global hotkey: `Cmd+Shift+V` to open history dropdown
- Global screenshot hotkey: default `F1` for region capture to clipboard
- Clipboard monitoring for plain text and images
- Consecutive dedupe + bounded history (100 items)
- Local persistence across restarts
- Configurable storage location for history and image files
- Optional launch at login
- Searchable status-bar dropdown history
- Pin-to-front for text and image snapshots
- Multiple pinned cards at once

## Controls

- Menubar icon click: open clipboard dropdown menu
- Click history item: copy back to clipboard (menu closes)
- `Option` + click history item: pin to front
- `Shift` + `Option` + click history item: delete from history
- Screenshot hotkey: configure in `Preferences > Screenshot Hotkey`, supports manual key capture (default `F1`)
- Storage location: configure in `Preferences > Storage Location`
- Launch at login: toggle in `Preferences`
- `Clear History`: clears all entries with confirmation

Pinned cards:

- Content-only window (no extra toolbar buttons)
- Drag to move
- Resize
- Right-click pinned content and choose `Delete Pin` to close/remove

Pinned appearance settings (in dropdown menu):

- `Window Shadow` toggle
- `Default Opacity` for new pinned windows

## Build & Run

Requirements:

- macOS 13+
- Xcode 15+ (or Swift 5.10+ toolchain)

Build:

```bash
swift build
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
./scripts/build_release_app.sh 1.0.0
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
- Launch at login is implemented via `~/Library/LaunchAgents/com.clippin.autostart.plist`.
- `build_release_app.sh` creates `release/ClipPin.app`, `release/ClipPin-<version>-macOS.zip`, and `.sha256`.

## Future Ideas (Post-MVP)

- Configurable history limit and hotkey
- Optional click-through mode for pinned cards
- Optional compact/expanded history row styles
- Built-in screenshot entry flow feeding the same snapshot pipeline
