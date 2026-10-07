# <img src="./assets/clippin-logo-flat.png" alt="ClipPin logo" width="36" /> ClipPin

[English](./README.md) | [**简体中文**](./README.zh-CN.md)

一个使用 Swift + AppKit 开发的轻量原生 macOS 工具：

- 剪贴板历史（文本 + 图片）
- 将任意历史条目 Pin 为始终置顶的悬浮窗口
- 框选屏幕区域识别文字，自动去除换行并复制，全程本机处理

## 下载与安装

在 [GitHub Releases](https://github.com/xiangtaowong/ClipPin/releases/latest) 下载 app 的 zip，解压后将 `ClipPin.app` 放到 `/Applications`。本次发布支持 macOS 13 及以上的 Apple Silicon Mac。

更新时先退出 ClipPin，再替换 `/Applications/ClipPin.app`。从这个位置启动应用，在 `系统设置 > 隐私与安全性 > 屏幕与系统音频录制` 中允许 ClipPin，截图和识字均需要这项权限。授权后退出并重新打开应用。

应用目前使用临时签名，更新后可能需要重新授权。若开关已打开但仍提示没有权限，先用 `-` 删除旧 ClipPin 记录，再用 `+` 添加 `/Applications/ClipPin.app`、打开权限并重启 ClipPin。

## 1.1.0 更新

- 新增独立的框选识字功能，使用高精度模式在本机识别中英文。
- 识别后自动去除换行并复制：中文行直接拼接，英文单词之间保留空格。
- 新增可自定义的 `Text Capture Hotkey`，与截图、Quick Paste 分别设置，并检查 ClipPin 内的快捷键冲突。
- 取消框选或没有识别到文字时保留原剪贴板；识字用的临时截图会删除。
- 保留截图复制、剪贴板历史、文字/图片 Pin 悬浮置顶及新建 Pin 的默认透明度设置。

版本记录见 [CHANGELOG.md](./CHANGELOG.md)。

## MVP 功能

- 菜单栏应用（Accessory 模式，无 Dock 图标）
- 全局快捷键：`Cmd+Shift+V` 打开历史下拉菜单
- 全局快速粘贴快捷键：默认 `Option+Shift+C`，在光标附近打开历史菜单
- 全局截图快捷键：默认 `F1`，区域截图到剪贴板
- 全局识字快捷键：默认 `Option+Shift+T`，框选后识别文字、去除换行并复制
- 监听剪贴板中的纯文本和图片
- 连续去重 + 有界历史（100 条）
- 本地持久化，重启后仍可用
- 可配置历史和图片文件存储位置
- 可选开机启动
- 可搜索的状态栏历史菜单
- 文本/图片条目可一键 Pin 到前台
- 支持同时存在多个 Pin 窗口

## 操作说明

### 快捷键

| 功能 | 首次安装默认按键 | 自定义示例 |
| --- | --- | --- |
| 框选截图，复制图片 | `F1` | `Cmd+1`（⌘1） |
| Quick Paste：在鼠标附近弹出历史 | `Option+Shift+C` | `Cmd+2`（⌘2） |
| 框选识字，去除换行并复制 | `Option+Shift+T` | `Cmd+3`（⌘3） |
| 打开菜单栏历史 | `Cmd+Shift+V`（⌘⇧V） | 固定 |

更新会保留你已保存的按键。`⌘1/2/3` 是自定义示例，不是首次安装默认值：可在 `Preferences > Screenshot / Quick Paste / Text Capture Hotkey > Set Manually...` 手动设定，`Current` 显示当前按键。请选用不与常用应用冲突的组合。

### 截图、识字与 Pin

1. **截图：**按 Screenshot 快捷键，拖动框选区域，然后用 `Cmd+V` 粘贴图片。
2. **识字：**按 Text Capture 快捷键，框选文字区域，等待 `Text copied` 提示，再用 `Cmd+V` 粘贴已去除换行的文字；`Esc` 取消框选。
3. **Pin：**通过 Quick Paste 或菜单栏图标打开历史，按住 `Option`（⌥）并左键单击图片或文字，即可悬浮置顶。识字结果也可以 Pin。
4. **透明度：**先在菜单栏下拉菜单中选择 `Default Opacity`，再创建 Pin。此设置只影响新建 Pin，已有窗口保持原透明度。

### 其他操作

- 点击菜单栏图标：打开剪贴板下拉菜单
- 全局快速粘贴：`Option` + `Shift` + `C` 在光标附近弹出历史菜单
- 快速粘贴快捷键：在 `Preferences > Quick Paste Hotkey` 配置，支持手动录制按键
- 点击历史条目：复制回剪贴板（菜单会关闭）
- `Option` + 点击条目：Pin 到前台
- `Shift` + `Option` + 点击条目：从历史中删除
- 截图快捷键：在 `Preferences > Screenshot Hotkey` 配置，支持手动录制按键（默认 `F1`）
- 框选识字：按 `Option+Shift+T`，框选文字区域，完成后按 `Cmd+V` 粘贴文字
- 识字快捷键：在 `Preferences > Text Capture Hotkey` 查看 `Current`，通过 `Set Manually...` 自定义
- 自动去除换行：中文行直接拼接，英文行之间补空格；识别的文字也会进入历史，可继续 Pin 为悬浮文字
- 存储位置：在 `Preferences > Storage Location` 配置
- 开机启动：在 `Preferences` 中切换
- `Clear History`：确认后清空所有条目

Pin 窗口：

- 仅显示内容本体（无额外工具栏按钮）
- 可拖动
- 可调整大小
- 右键内容并选择 `Delete Pin` 关闭/删除

Pin 外观设置（在下拉菜单中）：

- `Window Shadow` 开关
- 新建 Pin 窗口默认透明度 `Default Opacity`

## 构建与运行

环境要求：

- macOS 13+
- Xcode 15+（或 Swift 5.10+ 工具链）

构建：

```bash
swift build
```

使用 Swift 6+ 在 macOS 14+ 上运行识字和剪贴板测试（Swift Testing）：

```bash
swift test --disable-xctest
```

优化版 Release 构建（更小体积）：

```bash
./scripts/build_optimized_release.sh
```

构建可发布的 macOS `.app`（瘦身）+ GitHub Release `.zip` + 校验文件：

```bash
./scripts/build_release_app.sh
```

可选指定版本号：

```bash
./scripts/build_release_app.sh 1.1.0
```

运行：

```bash
swift run
```

## 数据存储

默认历史数据存储在：

- `~/Library/Application Support/ClipPin/history.json`
- `~/Library/Application Support/ClipPin/images/`

可在下拉菜单 `Storage Location` 中修改。

## 说明

- Pin 窗口是快照，不会随之后剪贴板变化而更新。
- MVP 阶段不支持应用重启后自动恢复 Pin 窗口。
- 截图快捷键调用系统命令 `screencapture -i -c`（交互式区域截图到剪贴板）。
- 框选识字使用 Apple Vision 在本机处理，支持中英文，不上传截图；与截图一样需要屏幕录制权限。
- 识字用的临时截图会删除，剪贴板只写入最终文字；取消框选或没有识别到文字时，原剪贴板保持不变。
- 识字结果会合并为一行，建议一次框选一个段落或单栏内容；不会保留表格和代码的原始排版。
- 开机启动通过 `~/Library/LaunchAgents/com.clippin.autostart.plist` 实现。
- `build_release_app.sh` 会生成 `release/ClipPin.app`、`release/ClipPin-<version>-macOS.zip` 和 `.sha256`。

## 后续想法（Post-MVP）

- 可配置历史上限和快捷键
- 可选点击穿透模式
- 可选历史条目紧凑/展开样式
- 内置截图到同一快照管线的流程
