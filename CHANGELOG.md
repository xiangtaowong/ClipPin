# Changelog

## 1.3.0 (2026-10-20)

### Added / 新增

- Crop tool with movable selection, eight resize handles, pixel dimensions, confirm/cancel, and undo/redo that restores source pixels and annotations. / 新增裁剪工具，支持移动选区、八个边角调整点、像素尺寸、确认/取消，以及可恢复原图和标注的撤销重做。

- Optional editor after region screenshots, enabled by default with a persistent Preferences toggle. / 框选截图后可自动编辑，设置开关默认开启并持久保存。
- Freehand drawing, highlighter, arrows, rectangles, ellipses, text, preset/custom colors, size control, undo/redo, clear, zoom, PNG export, and copy. / 支持涂鸦、高亮、箭头、矩形、椭圆、文字、预设及自定义颜色、粗细、撤销重做、清空、缩放、PNG 导出和复制。
- Native pixel resolution is preserved; canceling leaves the clipboard unchanged. OCR remains independent of the editor. / 保留原始像素、不缩放；取消不改变剪贴板，识字不经过编辑器。

## 1.2.4 - 2026-10-14

- Restore clipboard history thumbnails on macOS 27 by explicitly keeping content preview images visible, including Option and Option-Shift menu variants.
- Match Live Pin content to the source window's point size across display densities; add explicit edge/corner resize targets and drag-to-pan, with Command-drag to move the pin.
- Refresh idle Live Pin picker registration before each request and allow retrying a selection whose system callback was lost; increase the picker stream limit when adding another pin.

### Added

- `Live Pin…` in the menubar dropdown on macOS 14+, using the system single-window content picker and ScreenCaptureKit.
- Live floating window previews with the existing shadow preference, drag/resize, and support for multiple pins and Spaces.
- Option-drag crop, context-menu crop, whole-window reset, and Escape cancellation that preserves the previous crop.
- Pause/resume that stops and restarts capture; closing a pin stops capture and drops pending frames, including when a start/resume is in flight.
- Capture-unavailable and failure feedback; capture excludes ClipPin's own windows and does not capture audio or modify clipboard/history.
- Native capture with best-resolution selection and dynamic resolution updates as the source window changes size; frames reduced by the capture server are held back until native capture catches up. No silent resolution reduction for large windows.
- Original-window scale in a scrollable viewport: resizing changes the visible area without scaling the picture. `Actual Size (100%)` resets the viewport to the source window's point size; fractional scroll positions are aligned to display pixels.
- Explicit sRGB capture matching the frame decoder prevents display-profile data from being mislabelled, preserving text-edge gray levels when rendered back to the screen.
- Live Pins start fully opaque and provide their own per-pin opacity menu; clipboard opacity settings are preserved.
- Bounded frame delivery at up to 15 fps with a two-frame capture queue; no frame files or network transfers.
- Crop/capture geometry tests covering letterboxing, reverse selection, nested cropping, native Retina resolutions, source resize, and invalid selections; AppKit rendering tests cover source-size display across pixel densities, edge/corner resizing, drag-to-pan and clamping, per-pin opacity, and one-pixel contrast at matching display density.

Live Pin is disabled on macOS 13. Source windows must remain open and unminimized; source layout changes may require a new crop. Captured-window interaction and automatic pin restoration are not included.

### 快速使用 / Quick Start

- 点击菜单栏的 `Live Pin…` 并选择一个窗口，浮窗内容默认与原窗口同样大小。 / Choose `Live Pin…` in the menubar and select a window; content starts at the original window's size.
- 拖动四边或四角调整浮窗大小；在画面内拖动或滚动查看其他部分。 / Drag any edge or corner to resize the viewport; drag the image or scroll to pan.
- 按住 `Command` 拖动移动浮窗；按住 `Option` 拖动裁剪区域。 / Command-drag moves the pin; Option-drag crops a region.
- 右键可恢复原尺寸、暂停或恢复更新、调整透明度，或关闭 Live Pin。 / Right-click to restore actual size, pause/resume updates, adjust opacity, or close the pin.

Requires an Apple Silicon Mac with macOS 13+; Live Pin requires macOS 14+. Download the app zip, quit the previous version, replace `/Applications/ClipPin.app`, and reopen it. / 需要 Apple Silicon Mac 和 macOS 13+，Live Pin 需要 macOS 14+。下载并解压安装包，退出旧版后替换 Applications 中的 ClipPin，再重新打开。

## 1.1.0 - 2026-10-07

### Added

- Independent screen-region OCR with accurate, on-device Chinese and English text recognition.
- Automatic line-break removal and plain-text copying; Chinese lines join directly and English words retain spaces.
- Configurable Text Capture hotkey (default `Option+Shift+T`), with `Current` and `Set Manually...` controls.
- Brief text-capture feedback and safe handling of cancelled, failed, and empty captures without replacing the clipboard.
- OCR, reading-order, line-break, shortcut persistence, and isolated clipboard tests.

### Updated

- Shared shortcut capture and conflict validation across Screenshot, Quick Paste, and Text Capture.
- Shared capture coordination to avoid simultaneous screenshot selectors; OCR uses disposable temporary images.
- English and Chinese installation, upgrade, permission, keyboard, Pin, and opacity instructions.

Existing screenshot copying, clipboard history, text/image floating pins, and default opacity controls are retained. This release does not include OCR performance optimizations; first-use model initialization may take longer than later captures.

### 下载后操作 / Quick Start

| 功能 / Action | 默认快捷键 / Default | 自定义示例 / Custom example |
| --- | --- | --- |
| 截图并复制图片 / Screenshot | `F1` | `Cmd+1` |
| 弹出历史 / Quick Paste | `Option+Shift+C` | `Cmd+2` |
| 框选识字、去除换行并复制 / Text Capture | `Option+Shift+T` | `Cmd+3` |
| 菜单栏历史 / Menubar history | `Cmd+Shift+V` | Fixed |

- 以上 `Cmd+1/2/3` 需要在 Preferences 中手动设置，已有自定义快捷键会保留。 / Set the examples manually in Preferences; existing shortcuts survive updates.
- 框选识字后等待 `Text copied`，再按 `Cmd+V` 粘贴；`Esc` 取消。 / Select text, wait for `Text copied`, then paste with `Cmd+V`; `Esc` cancels.
- 历史条目：普通单击复制，`Option+单击` Pin，`Option+Shift+单击` 删除。 / Click copies; `Option+click` pins; `Option+Shift+click` deletes.
- `Default Opacity` 设置新建 Pin 的透明度；右键悬浮内容选择 `Delete Pin` 关闭。 / `Default Opacity` affects new pins; right-click a pin and choose `Delete Pin` to close it.

### Installation / 安装与权限

- Download `ClipPin-1.1.0-macOS.zip`, unzip it, and move `ClipPin.app` to `/Applications`. Quit the previous version before replacing it. / 下载 zip 并解压，将 app 放到 Applications；覆盖更新前先退出旧版。
- Requires an Apple Silicon Mac with macOS 13+. / 需要 macOS 13 及以上的 Apple Silicon Mac。
- Screenshots and OCR require Screen Recording permission. Grant it to `/Applications/ClipPin.app`, then quit and reopen the app. / 截图和识字需要屏幕录制权限，授权后重启应用。
- Ad-hoc signatures may require reauthorization after updates. If permission is enabled but capture fails, remove the old ClipPin entry in System Settings and add the installed app again. / 临时签名可能导致更新后需重新授权；开关已开却仍被拒绝时，删除旧记录并重新添加安装好的 app。
- OCR runs locally, but flattens output to one line: select a single paragraph or column. Table and code formatting is not preserved. / 识字在本机进行，结果合并为一行；建议框选单个段落或单栏，不保留表格和代码排版。

## 1.0.1 - 2026-04-03

- Allow Command-based custom Quick Paste shortcuts, including `Cmd+2`.

## 1.0.0 - 2026-04-01

- Initial release: clipboard history, region screenshots, floating text/image pins, appearance settings, and app icon.
