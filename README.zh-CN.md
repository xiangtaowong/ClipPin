# <img src="./assets/clippin-logo-flat.png" alt="ClipPin logo" width="36" /> ClipPin

[English](./README.md) | [**简体中文**](./README.zh-CN.md)

一个使用 Swift + AppKit 开发的轻量原生 macOS 工具：

- 剪贴板历史（文本 + 图片）
- 将任意历史条目 Pin 为始终置顶的悬浮窗口

## MVP 功能

- 菜单栏应用（Accessory 模式，无 Dock 图标）
- 全局快捷键：`Cmd+Shift+V` 打开历史下拉菜单
- 全局快速粘贴快捷键：默认 `Option+Shift+C`，在光标附近打开历史菜单
- 全局截图快捷键：默认 `F1`，区域截图到剪贴板
- 监听剪贴板中的纯文本和图片
- 连续去重 + 有界历史（100 条）
- 本地持久化，重启后仍可用
- 可配置历史和图片文件存储位置
- 可选开机启动
- 可搜索的状态栏历史菜单
- 文本/图片条目可一键 Pin 到前台
- 支持同时存在多个 Pin 窗口

## 操作说明

- 点击菜单栏图标：打开剪贴板下拉菜单
- 全局快速粘贴：`Option` + `Shift` + `C` 在光标附近弹出历史菜单
- 快速粘贴快捷键：在 `Preferences > Quick Paste Hotkey` 配置，支持手动录制按键
- 点击历史条目：复制回剪贴板（菜单会关闭）
- `Option` + 点击条目：Pin 到前台
- `Shift` + `Option` + 点击条目：从历史中删除
- 截图快捷键：在 `Preferences > Screenshot Hotkey` 配置，支持手动录制按键（默认 `F1`）
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
./scripts/build_release_app.sh 1.0.0
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
- 开机启动通过 `~/Library/LaunchAgents/com.clippin.autostart.plist` 实现。
- `build_release_app.sh` 会生成 `release/ClipPin.app`、`release/ClipPin-<version>-macOS.zip` 和 `.sha256`。

## 后续想法（Post-MVP）

- 可配置历史上限和快捷键
- 可选点击穿透模式
- 可选历史条目紧凑/展开样式
- 内置截图到同一快照管线的流程
