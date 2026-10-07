# Changelog

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
