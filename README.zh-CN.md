# <img src="./assets/clippin-logo-flat.png" alt="ClipPin logo" width="36" /> ClipPin

[English](./README.md) | [**简体中文**](./README.zh-CN.md)

一个使用 Swift + AppKit 开发的轻量原生 macOS 工具：

- 剪贴板历史（文本 + 图片）
- 将任意历史条目 Pin 为始终置顶的悬浮窗口
- 框选屏幕区域识别文字，自动去除换行并复制，全程本机处理
- 将应用窗口的实时画面置顶，也能裁出其中的字幕区域（macOS 14+）

## 下载与安装

在 [GitHub Releases](https://github.com/xiangtaowong/ClipPin/releases/latest) 下载 app 的 zip，解压后将 `ClipPin.app` 放到 `/Applications`。本次发布支持 macOS 13 及以上的 Apple Silicon Mac。

更新时先退出 ClipPin，再替换 `/Applications/ClipPin.app`。从这个位置启动应用，在 `系统设置 > 隐私与安全性 > 屏幕与系统音频录制` 中允许 ClipPin，截图和识字均需要这项权限。授权后退出并重新打开应用。

应用目前使用临时签名，更新后可能需要重新授权。若开关已打开但仍提示没有权限，先用 `-` 删除旧 ClipPin 记录，再用 `+` 添加 `/Applications/ClipPin.app`、打开权限并重启 ClipPin。

## 1.2.4 更新

- Live Pin 应用窗口实时置顶，支持裁剪、暂停/恢复和单独调整透明度（macOS 14+）。
- 默认与原窗口同样大小，跨不同像素密度的显示器也保持一致。
- 四边和四角自由调整浮窗大小；拖动画面或滚动查看内容，Command 拖动移动浮窗。
- 选窗回调丢失后可以重新选择；修复 macOS 27 的剪贴板预览图显示。
- 原有截图、本机识字、剪贴板历史和文本/图片 Pin 继续可用。

详见 [CHANGELOG.md](./CHANGELOG.md)。

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

### Live Pin 实时置顶（macOS 14+）

1. 打开 ClipPin 菜单栏下拉菜单，选择 `Live Pin…`。
2. 在系统选择器中选择一个应用窗口，ClipPin 会显示它的实时悬浮画面。
3. 按住 `Option` 在悬浮画面中拖动框选，可只保留字幕等区域。也可以右键选择 `Crop Region…` 后框选；按 `Esc` 取消并保留之前的裁剪。
4. 拖动任意边缘或四角可自由调整浮窗大小；在画面内拖动或滚动查看范围外的内容，按住 `Command` 拖动可移动浮窗；Live Pin 默认完全不透明，以便阅读文字，阴影仍沿用原设置。需要半透明时，可在每个 Live Pin 的右键 `Opacity` 菜单调整。
5. 右键可选择 `Actual Size (100%)` 原尺寸显示、`Show Whole Window` 恢复整窗、`Pause Live Pin` / `Resume Live Pin` 暂停或恢复，或 `Close Live Pin` 关闭。

Live Pin 默认按原窗口的屏幕尺寸显示，即使原窗口和浮窗所在显示器的像素密度不同，文字也保持与原窗口一样大。缩小浮窗只改变可见范围，画面不会跟着缩小或放大；拖动画面或滚动可查看范围外的内容。`Actual Size (100%)` 会重置视图，并在屏幕可用范围内按原窗口尺寸展开浮窗。源窗口变大时同步更新捕获分辨率，在新分辨率就绪前保留上一帧清晰画面。大窗口不会被静默压缩；达到系统捕获限制或捕获失败时会显示错误。

原窗口可以被其他窗口遮住，或移到另一块显示器，但要保持打开且不要最小化。最小化或窗口不可用时画面会暂停，恢复原窗口后通常会继续更新；源窗口关闭或捕获失败时会显示状态，必要时关闭该 Pin 并重新选择。裁剪跟随原窗口中的比例区域，源窗口重新排版时文字可能移出选区，需要重新裁剪。

Live Pin 使用 ScreenCaptureKit 和系统窗口选择器，仅在本机显示选中的窗口；不捕获音频、不做识字、不更改剪贴板，也不保存或上传画面。暂停会停止捕获，关闭会释放捕获资源。支持多个实时 Pin，退出后不自动恢复。macOS 13 上此入口禁用，剪贴板 Pin、截图和识字仍可使用。

Pin 窗口：

- 仅显示内容本体（无额外工具栏按钮）
- 可拖动
- 可调整大小
- 右键内容并选择 `Delete Pin` 关闭/删除

Pin 外观设置（在下拉菜单中）：

- `Window Shadow` 开关
- 新建剪贴板 Pin 的默认透明度 `Default Opacity`；Live Pin 在自己的右键菜单中调整透明度

## 构建与运行

环境要求：

- macOS 13+
- Xcode 15+（或 Swift 5.10+ 工具链）

构建：

```bash
swift build
```

使用 Swift 6+ 在 macOS 14+ 上运行识字、剪贴板和 Live Pin 裁剪坐标测试（Swift Testing）：

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

- 剪贴板 Pin 是快照，不会随之后剪贴板变化而更新；Live Pin 会随选中的原窗口实时更新。
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
