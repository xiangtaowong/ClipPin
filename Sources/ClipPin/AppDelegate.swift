import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let historyHotKeySignature: OSType = 0x4342484D // "CBHM"
    private let quickPasteHotKeySignature: OSType = 0x43425150 // "CBQP"
    private let screenshotHotKeySignature: OSType = 0x43425343 // "CBSC"
    private let maxHistoryItems = 100

    private var statusItem: NSStatusItem?
    private var historyStore: HistoryStore?
    private var clipboardMonitor: ClipboardMonitor?
    private var historyMenuController: HistoryMenuController?
    private var pinAppearanceStore: PinAppearanceStore?
    private var pinboardManager: PinboardManager?
    private var historyHotKeyManager: GlobalHotKeyManager?
    private var quickPasteHotKeyManager: GlobalHotKeyManager?
    private var quickPasteHotKeyStore: QuickPasteHotKeyStore?
    private var screenshotHotKeyManager: GlobalHotKeyManager?
    private var screenshotHotKeyStore: ScreenshotHotKeyStore?
    private var screenshotService: ScreenshotService?
    private var storageLocationStore: StorageLocationStore?
    private var launchAtLoginService: LaunchAtLoginService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupStatusItem()
        bootstrapApp()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
    }

    @objc
    private func showHistoryMenu(_ sender: Any?) {
        historyMenuController?.prepareForDisplay()
        statusItem?.button?.performClick(nil)
    }

    @objc
    private func showQuickPasteMenu(_ sender: Any?) {
        presentHistoryMenuNearCursor()
    }

    @objc
    private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else {
            return
        }

        button.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "ClipPin")
        button.toolTip = "ClipPin"
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)

        let appMenu = NSMenu()
        let showItem = NSMenuItem(
            title: "Open Clipboard Menu",
            action: #selector(showHistoryMenu(_:)),
            keyEquivalent: "v"
        )
        showItem.keyEquivalentModifierMask = [.command, .shift]
        showItem.target = self
        appMenu.addItem(showItem)

        let quickPasteItem = NSMenuItem(
            title: "Quick Paste Menu",
            action: #selector(showQuickPasteMenu(_:)),
            keyEquivalent: ""
        )
        quickPasteItem.target = self
        appMenu.addItem(quickPasteItem)
        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit ClipPin",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        appMenu.addItem(quitItem)
        appItem.submenu = appMenu

        NSApp.mainMenu = mainMenu
    }

    private func bootstrapApp() {
        do {
            let storageLocationStore = StorageLocationStore()
            let launchAtLoginService = LaunchAtLoginService()

            let store = try makeInitialHistoryStore(using: storageLocationStore)
            let monitor = ClipboardMonitor()
            let historyMenuController = HistoryMenuController()
            let pinAppearanceStore = PinAppearanceStore()
            let pinboardManager = PinboardManager(
                historyStore: store,
                appearanceStore: pinAppearanceStore
            )
            let historyHotKeyManager = GlobalHotKeyManager(signature: historyHotKeySignature)
            let quickPasteHotKeyManager = GlobalHotKeyManager(signature: quickPasteHotKeySignature)
            let quickPasteHotKeyStore = QuickPasteHotKeyStore()
            let screenshotHotKeyManager = GlobalHotKeyManager(signature: screenshotHotKeySignature)
            let screenshotHotKeyStore = ScreenshotHotKeyStore()
            let screenshotService = ScreenshotService()
            screenshotService.onPermissionDenied = { [weak self] in
                self?.presentScreenRecordingPermissionAlert()
            }

            self.historyStore = store
            self.clipboardMonitor = monitor
            self.historyMenuController = historyMenuController
            self.pinAppearanceStore = pinAppearanceStore
            self.pinboardManager = pinboardManager
            self.historyHotKeyManager = historyHotKeyManager
            self.quickPasteHotKeyManager = quickPasteHotKeyManager
            self.quickPasteHotKeyStore = quickPasteHotKeyStore
            self.screenshotHotKeyManager = screenshotHotKeyManager
            self.screenshotHotKeyStore = screenshotHotKeyStore
            self.screenshotService = screenshotService
            self.storageLocationStore = storageLocationStore
            self.launchAtLoginService = launchAtLoginService

            statusItem?.menu = historyMenuController.menu

            historyMenuController.imageProvider = { [weak self] item in
                self?.historyStore?.image(for: item)
            }

            historyMenuController.onPinRequest = { [weak self] item in
                self?.pinboardManager?.pin(item: item)
            }

            historyMenuController.onCopyRequest = { [weak self] item in
                self?.historyStore?.copyToPasteboard(item: item)
            }

            historyMenuController.onDeleteRequest = { [weak self] item in
                self?.historyStore?.remove(itemID: item.id)
            }

            historyMenuController.onClearRequest = { [weak self] in
                self?.historyStore?.clear()
            }

            historyMenuController.onQuitRequest = { [weak self] in
                self?.quit(nil)
            }

            historyMenuController.pinAppearanceSettingsProvider = { [weak pinAppearanceStore] in
                pinAppearanceStore?.settings ?? .default
            }

            historyMenuController.onWindowShadowChanged = { [weak pinAppearanceStore] enabled in
                pinAppearanceStore?.setWindowShadowEnabled(enabled)
            }

            historyMenuController.onDefaultOpacityChanged = { [weak pinAppearanceStore] opacity in
                pinAppearanceStore?.setDefaultOpacity(opacity)
            }

            historyMenuController.quickPasteHotKeyProvider = { [weak quickPasteHotKeyStore] in
                quickPasteHotKeyStore?.shortcut ?? .quickPasteDefault
            }

            historyMenuController.onQuickPasteHotKeyManualRequest = { [weak self] in
                self?.promptForQuickPasteHotKeyCapture()
            }

            historyMenuController.screenshotHotKeyProvider = { [weak screenshotHotKeyStore] in
                screenshotHotKeyStore?.shortcut ?? .screenshotDefault
            }

            historyMenuController.onScreenshotHotKeyManualRequest = { [weak self] in
                self?.promptForScreenshotHotKeyCapture()
            }

            historyMenuController.storageLocationProvider = { [weak self] in
                self?.currentStorageLocationURL()
            }

            historyMenuController.defaultStorageLocationProvider = { [weak self] in
                self?.defaultStorageLocationURL()
            }

            historyMenuController.onStorageLocationRequest = { [weak self] in
                self?.promptForStorageLocationSelection()
            }

            historyMenuController.onResetStorageLocationRequest = { [weak self] in
                self?.resetStorageLocationToDefault()
            }

            historyMenuController.launchAtLoginEnabledProvider = { [weak launchAtLoginService] in
                launchAtLoginService?.isEnabled ?? false
            }

            historyMenuController.onLaunchAtLoginChanged = { [weak self] enabled in
                self?.setLaunchAtLoginEnabled(enabled)
            }

            bindHistoryStore(store, to: historyMenuController)

            monitor.onSnapshot = { [weak self] snapshot in
                self?.historyStore?.add(snapshot)
            }
            monitor.start()

            historyHotKeyManager.onTrigger = { [weak self] in
                self?.showHistoryMenu(nil)
            }
            if !historyHotKeyManager.register(shortcut: .clipboardMenuDefault) {
                presentErrorAlert(
                    title: "Failed to Register Hotkey",
                    message: "Unable to register default history hotkey Cmd+Shift+V."
                )
            }

            quickPasteHotKeyManager.onTrigger = { [weak self] in
                self?.presentHistoryMenuNearCursor()
            }
            let quickPasteShortcut: HotKeyShortcut
            if isAllowedQuickPasteShortcut(quickPasteHotKeyStore.shortcut) {
                quickPasteShortcut = quickPasteHotKeyStore.shortcut
            } else {
                quickPasteShortcut = .quickPasteDefault
                quickPasteHotKeyStore.setShortcut(.quickPasteDefault)
            }
            if !quickPasteHotKeyManager.register(shortcut: quickPasteShortcut) {
                quickPasteHotKeyStore.setShortcut(.quickPasteDefault)
                if !quickPasteHotKeyManager.register(shortcut: .quickPasteDefault) {
                    presentErrorAlert(
                        title: "Failed to Register Hotkey",
                        message: "Unable to register quick paste hotkey. Set it manually in Preferences."
                    )
                }
            }

            screenshotHotKeyManager.onTrigger = { [weak screenshotService] in
                screenshotService?.captureSelectionToClipboard()
            }
            if !screenshotHotKeyManager.register(shortcut: screenshotHotKeyStore.shortcut) {
                screenshotHotKeyStore.setShortcut(.screenshotDefault)
                _ = screenshotHotKeyManager.register(shortcut: .screenshotDefault)
            }

            DispatchQueue.global(qos: .utility).async {
                launchAtLoginService.synchronizeConfigurationIfNeeded()
            }
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "ClipPin failed to start"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    private func bindHistoryStore(_ store: HistoryStore, to menuController: HistoryMenuController) {
        historyStore?.onChange = nil
        historyStore = store
        store.onChange = { [weak menuController] items in
            menuController?.setItems(items)
        }
        menuController.setItems(store.items)
    }

    private func makeInitialHistoryStore(using storageLocationStore: StorageLocationStore) throws -> HistoryStore {
        let configuredRoot = try storageLocationStore.currentRootDirectoryURL().standardizedFileURL

        do {
            return try HistoryStore(
                maxItems: maxHistoryItems,
                rootDirectoryURL: configuredRoot
            )
        } catch {
            let defaultRoot = try storageLocationStore.defaultRootDirectoryURL().standardizedFileURL
            guard configuredRoot != defaultRoot else {
                throw error
            }

            storageLocationStore.resetToDefault()
            let fallbackStore = try HistoryStore(
                maxItems: maxHistoryItems,
                rootDirectoryURL: defaultRoot
            )

            presentErrorAlert(
                title: "Storage Location Reset",
                message: "Configured storage folder is unavailable. Switched back to default location."
            )
            return fallbackStore
        }
    }

    private func currentStorageLocationURL() -> URL? {
        guard let storageLocationStore else {
            return nil
        }
        return try? storageLocationStore.currentRootDirectoryURL()
    }

    private func defaultStorageLocationURL() -> URL? {
        guard let storageLocationStore else {
            return nil
        }
        return try? storageLocationStore.defaultRootDirectoryURL()
    }

    private func promptForStorageLocationSelection() {
        guard let storageLocationStore else {
            return
        }

        let panel = NSOpenPanel()
        panel.title = "Choose ClipPin Storage Folder"
        panel.message = "History metadata and image files will be saved in this folder."
        panel.prompt = "Select"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = try? storageLocationStore.currentRootDirectoryURL()

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let selectedURL = panel.urls.first else {
            return
        }

        applyStorageLocation(selectedURL, useDefaultLocation: false)
    }

    private func resetStorageLocationToDefault() {
        guard let defaultURL = defaultStorageLocationURL() else {
            return
        }
        applyStorageLocation(defaultURL, useDefaultLocation: true)
    }

    private func applyStorageLocation(_ url: URL, useDefaultLocation: Bool) {
        guard let storageLocationStore else {
            return
        }

        do {
            let targetURL = url.standardizedFileURL
            let currentURL = try storageLocationStore.currentRootDirectoryURL().standardizedFileURL
            if currentURL != targetURL {
                try switchHistoryStore(to: targetURL)
            }

            if useDefaultLocation {
                storageLocationStore.resetToDefault()
            } else {
                storageLocationStore.setCustomRootDirectoryURL(targetURL)
            }
        } catch {
            presentErrorAlert(
                title: "Failed to Change Storage Location",
                message: error.localizedDescription
            )
        }
    }

    private func switchHistoryStore(to rootDirectoryURL: URL) throws {
        guard let menuController = historyMenuController,
              let pinAppearanceStore
        else {
            return
        }

        let newStore = try HistoryStore(
            maxItems: maxHistoryItems,
            rootDirectoryURL: rootDirectoryURL
        )

        if let oldStore = historyStore {
            migrateHistoryIfNeeded(from: oldStore, to: newStore)
        }

        bindHistoryStore(newStore, to: menuController)
        pinboardManager = PinboardManager(
            historyStore: newStore,
            appearanceStore: pinAppearanceStore
        )
    }

    private func migrateHistoryIfNeeded(from oldStore: HistoryStore, to newStore: HistoryStore) {
        guard newStore.items.isEmpty else {
            return
        }

        for item in oldStore.items.reversed() {
            guard let snapshot = migrationSnapshot(for: item, in: oldStore) else {
                continue
            }
            newStore.add(snapshot)
        }
    }

    private func migrationSnapshot(for item: ClipItem, in store: HistoryStore) -> ClipSnapshot? {
        switch item.kind {
        case .text:
            guard let text = item.text else {
                return nil
            }
            return ClipSnapshot(
                createdAt: item.createdAt,
                sourceAppName: item.sourceAppName,
                contentHash: item.contentHash,
                payload: .text(text)
            )
        case .image:
            guard let image = store.image(for: item),
                  let normalized = ImageUtilities.normalizedPNGData(from: image)
            else {
                return nil
            }

            return ClipSnapshot(
                createdAt: item.createdAt,
                sourceAppName: item.sourceAppName,
                contentHash: item.contentHash,
                payload: .image(data: normalized.data, pixelSize: normalized.pixelSize)
            )
        }
    }

    private func promptForQuickPasteHotKeyCapture() {
        guard let current = quickPasteHotKeyStore?.shortcut else {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Set Quick Paste Hotkey"
        alert.informativeText = "Press the key combination you want to use.\nPress Esc to cancel."
        alert.addButton(withTitle: "Cancel")

        let currentLabel = NSTextField(labelWithString: "Current: \(current.displayString)")
        currentLabel.font = .systemFont(ofSize: 12)
        currentLabel.textColor = .secondaryLabelColor

        let listeningLabel = NSTextField(labelWithString: "Listening…")
        listeningLabel.font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        listeningLabel.alignment = .center

        let accessory = NSStackView(views: [currentLabel, listeningLabel])
        accessory.orientation = .vertical
        accessory.spacing = 8
        accessory.frame = NSRect(x: 0, y: 0, width: 280, height: 44)
        alert.accessoryView = accessory

        var capturedShortcut: HotKeyShortcut?
        var monitor: Any?

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else {
                return event
            }

            if event.keyCode == UInt16(kVK_Escape) {
                NSApp.stopModal(withCode: .cancel)
                alert.window.orderOut(nil)
                return nil
            }

            guard !isModifierOnlyKeyCode(event.keyCode) else {
                NSSound.beep()
                return nil
            }

            let shortcut = HotKeyShortcut(
                keyCode: UInt32(event.keyCode),
                modifiers: carbonModifiers(from: event.modifierFlags)
            )

            guard isAllowedQuickPasteShortcut(shortcut) else {
                listeningLabel.stringValue = "Use ⌥/⌃ with non-F keys"
                NSSound.beep()
                return nil
            }

            if shortcut == .clipboardMenuDefault || shortcut == (screenshotHotKeyStore?.shortcut ?? .screenshotDefault) {
                listeningLabel.stringValue = "Reserved: \(shortcut.displayString)"
                NSSound.beep()
                return nil
            }

            capturedShortcut = shortcut
            listeningLabel.stringValue = "Selected: \(shortcut.displayString)"
            NSApp.stopModal(withCode: .OK)
            alert.window.orderOut(nil)
            return nil
        }

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        if let monitor {
            NSEvent.removeMonitor(monitor)
        }

        if response == .OK, let capturedShortcut {
            applyQuickPasteHotKey(capturedShortcut, persistSelection: true)
        }

        historyMenuController?.prepareForDisplay()
    }

    private func promptForScreenshotHotKeyCapture() {
        guard let current = screenshotHotKeyStore?.shortcut else {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Set Screenshot Hotkey"
        alert.informativeText = "Press the key combination you want to use.\nPress Esc to cancel."
        alert.addButton(withTitle: "Cancel")

        let currentLabel = NSTextField(labelWithString: "Current: \(current.displayString)")
        currentLabel.font = .systemFont(ofSize: 12)
        currentLabel.textColor = .secondaryLabelColor

        let listeningLabel = NSTextField(labelWithString: "Listening…")
        listeningLabel.font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        listeningLabel.alignment = .center

        let accessory = NSStackView(views: [currentLabel, listeningLabel])
        accessory.orientation = .vertical
        accessory.spacing = 8
        accessory.frame = NSRect(x: 0, y: 0, width: 280, height: 44)
        alert.accessoryView = accessory

        var capturedShortcut: HotKeyShortcut?
        var monitor: Any?

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else {
                return event
            }

            if event.keyCode == UInt16(kVK_Escape) {
                NSApp.stopModal(withCode: .cancel)
                alert.window.orderOut(nil)
                return nil
            }

            guard !isModifierOnlyKeyCode(event.keyCode) else {
                NSSound.beep()
                return nil
            }

            let shortcut = HotKeyShortcut(
                keyCode: UInt32(event.keyCode),
                modifiers: carbonModifiers(from: event.modifierFlags)
            )

            guard isAllowedManualShortcut(shortcut) else {
                listeningLabel.stringValue = "Use ⌘/⌥/⌃ with non-F keys"
                NSSound.beep()
                return nil
            }

            if shortcut == .clipboardMenuDefault || shortcut == (quickPasteHotKeyStore?.shortcut ?? .quickPasteDefault) {
                listeningLabel.stringValue = "Reserved: \(shortcut.displayString)"
                NSSound.beep()
                return nil
            }

            capturedShortcut = shortcut
            listeningLabel.stringValue = "Selected: \(shortcut.displayString)"
            NSApp.stopModal(withCode: .OK)
            alert.window.orderOut(nil)
            return nil
        }

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        if let monitor {
            NSEvent.removeMonitor(monitor)
        }

        if response == .OK, let capturedShortcut {
            applyScreenshotHotKey(capturedShortcut, persistSelection: true)
        }

        historyMenuController?.prepareForDisplay()
    }

    private func applyScreenshotHotKey(_ shortcut: HotKeyShortcut, persistSelection: Bool) {
        guard let screenshotHotKeyManager, let screenshotHotKeyStore else {
            return
        }

        if shortcut == .clipboardMenuDefault || shortcut == (quickPasteHotKeyStore?.shortcut ?? .quickPasteDefault) {
            presentErrorAlert(
                title: "Hotkey Conflict",
                message: "This shortcut is already reserved for clipboard menu actions."
            )
            return
        }

        let previous = screenshotHotKeyStore.shortcut
        guard screenshotHotKeyManager.register(shortcut: shortcut) else {
            _ = screenshotHotKeyManager.register(shortcut: previous)
            presentErrorAlert(
                title: "Failed to Set Screenshot Hotkey",
                message: "That shortcut is unavailable. Please choose a different one."
            )
            return
        }

        if persistSelection {
            screenshotHotKeyStore.setShortcut(shortcut)
        }
    }

    private func applyQuickPasteHotKey(_ shortcut: HotKeyShortcut, persistSelection: Bool) {
        guard let quickPasteHotKeyManager, let quickPasteHotKeyStore else {
            return
        }

        guard isAllowedQuickPasteShortcut(shortcut) else {
            presentErrorAlert(
                title: "Unsupported Quick Paste Hotkey",
                message: "Use Option/Control combinations or function keys to avoid app shortcut conflicts."
            )
            return
        }

        if shortcut == .clipboardMenuDefault || shortcut == (screenshotHotKeyStore?.shortcut ?? .screenshotDefault) {
            presentErrorAlert(
                title: "Hotkey Conflict",
                message: "This shortcut is already reserved for another action."
            )
            return
        }

        let previous = quickPasteHotKeyStore.shortcut
        guard quickPasteHotKeyManager.register(shortcut: shortcut) else {
            _ = quickPasteHotKeyManager.register(shortcut: previous)
            presentErrorAlert(
                title: "Failed to Set Quick Paste Hotkey",
                message: "That shortcut is unavailable. Please choose a different one."
            )
            return
        }

        if persistSelection {
            quickPasteHotKeyStore.setShortcut(shortcut)
        }
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        let normalized = flags.intersection(.deviceIndependentFlagsMask)
        var result: UInt32 = 0
        if normalized.contains(.command) {
            result |= UInt32(cmdKey)
        }
        if normalized.contains(.shift) {
            result |= UInt32(shiftKey)
        }
        if normalized.contains(.option) {
            result |= UInt32(optionKey)
        }
        if normalized.contains(.control) {
            result |= UInt32(controlKey)
        }
        return result
    }

    private func isModifierOnlyKeyCode(_ keyCode: UInt16) -> Bool {
        switch Int(keyCode) {
        case kVK_Command,
             kVK_Shift,
             kVK_CapsLock,
             kVK_Option,
             kVK_Control,
             kVK_RightCommand,
             kVK_RightShift,
             kVK_RightOption,
             kVK_RightControl,
             kVK_Function:
            return true
        default:
            return false
        }
    }

    private func isAllowedManualShortcut(_ shortcut: HotKeyShortcut) -> Bool {
        let keyCode = Int(shortcut.keyCode)
        if isFunctionKeyCode(keyCode) {
            return true
        }

        let nonShiftModifiers = UInt32(cmdKey | optionKey | controlKey)
        return (shortcut.modifiers & nonShiftModifiers) != 0
    }

    private func isAllowedQuickPasteShortcut(_ shortcut: HotKeyShortcut) -> Bool {
        let keyCode = Int(shortcut.keyCode)
        if isFunctionKeyCode(keyCode) {
            return true
        }

        let stableModifiers = UInt32(optionKey | controlKey)
        return (shortcut.modifiers & stableModifiers) != 0
    }

    private func isFunctionKeyCode(_ keyCode: Int) -> Bool {
        switch keyCode {
        case kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
             kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12:
            return true
        default:
            return false
        }
    }

    private func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            try launchAtLoginService?.setEnabled(enabled)
        } catch {
            presentErrorAlert(
                title: "Failed to Update Launch at Login",
                message: error.localizedDescription
            )
        }
    }

    private func presentErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    private func presentScreenRecordingPermissionAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "ClipPin needs Screen Recording permission for region screenshots to capture other app windows correctly."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    private func presentHistoryMenuNearCursor() {
        let showMenu = { [weak self] in
            guard let self, let historyMenuController else {
                return
            }

            historyMenuController.prepareForDisplay()
            NSApp.activate(ignoringOtherApps: true)

            let location = NSEvent.mouseLocation
            let anchor = NSPoint(x: location.x + 2, y: location.y - 2)
            historyMenuController.menu.popUp(positioning: nil, at: anchor, in: nil)
        }

        if Thread.isMainThread {
            showMenu()
        } else {
            DispatchQueue.main.async(execute: showMenu)
        }
    }
}
