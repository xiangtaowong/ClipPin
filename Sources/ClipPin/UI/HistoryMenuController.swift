import AppKit

final class HistoryMenuController: NSObject, NSMenuDelegate, NSSearchFieldDelegate {
    let menu = NSMenu()

    var onPinRequest: ((ClipItem) -> Void)?
    var onCopyRequest: ((ClipItem) -> Void)?
    var onDeleteRequest: ((ClipItem) -> Void)?
    var onClearRequest: (() -> Void)?
    var onQuitRequest: (() -> Void)?
    var imageProvider: ((ClipItem) -> NSImage?)?
    var pinAppearanceSettingsProvider: (() -> PinAppearanceSettings)?
    var onWindowShadowChanged: ((Bool) -> Void)?
    var onDefaultOpacityChanged: ((CGFloat) -> Void)?
    var quickPasteHotKeyProvider: (() -> HotKeyShortcut)?
    var onQuickPasteHotKeyManualRequest: (() -> Void)?
    var screenshotHotKeyProvider: (() -> HotKeyShortcut)?
    var onScreenshotHotKeyManualRequest: (() -> Void)?
    var storageLocationProvider: (() -> URL?)?
    var defaultStorageLocationProvider: (() -> URL?)?
    var onStorageLocationRequest: (() -> Void)?
    var onResetStorageLocationRequest: (() -> Void)?
    var launchAtLoginEnabledProvider: (() -> Bool)?
    var onLaunchAtLoginChanged: ((Bool) -> Void)?

    private let menuWidth: CGFloat = 360
    private let searchField = NSSearchField()
    private let searchItem = NSMenuItem()
    private var allItems: [ClipItem] = []
    private let defaultVisibleItems = 10
    private let maxVisibleItems = 50
    private let relativeDateFormatter = RelativeDateTimeFormatter()
    private let opacityPercentOptions = [30, 40, 50, 60, 70, 80, 90, 100]
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var lastModifierFlags: NSEvent.ModifierFlags = []
    private var lastClickModifierFlags: NSEvent.ModifierFlags = []
    private var currentStartIndex: Int
    private var menuNeedsRebuild = true
    private var isMenuVisible = false

    private enum ClipSelectionAction: Int {
        case copy = 0
        case pin = 1
        case delete = 2
    }

    override init() {
        self.currentStartIndex = 0
        super.init()
        setupMenu()
    }

    func setItems(_ items: [ClipItem]) {
        allItems = items
        menuNeedsRebuild = true
        if isMenuVisible {
            rebuildMenuContents()
            menuNeedsRebuild = false
        }
    }

    func prepareForDisplay() {
        if menuNeedsRebuild || isMenuVisible {
            rebuildMenuContents()
            menuNeedsRebuild = false
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuVisible = true
        installModifierTracking()
        currentStartIndex = 0
        searchField.stringValue = ""
        rebuildMenuContents()
        menuNeedsRebuild = false

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.searchField.window?.makeFirstResponder(self.searchField)
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuVisible = false
        removeModifierTracking()
    }

    func controlTextDidChange(_ obj: Notification) {
        currentStartIndex = 0
        rebuildMenuContents()
        menuNeedsRebuild = false
    }

    private func setupMenu() {
        menu.autoenablesItems = false
        menu.delegate = self

        searchField.frame = NSRect(x: 10, y: 4, width: menuWidth - 20, height: 24)
        searchField.placeholderString = "Search history"
        searchField.sendsSearchStringImmediately = true
        searchField.delegate = self
        searchField.focusRingType = .none

        let container = NSView(frame: NSRect(x: 0, y: 0, width: menuWidth, height: 32))
        container.addSubview(searchField)
        searchItem.view = container
        menu.addItem(searchItem)
        menu.addItem(.separator())
    }

    private func installModifierTracking() {
        removeModifierTracking()
        let initialFlags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        lastModifierFlags = initialFlags
        lastClickModifierFlags = initialFlags

        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.flagsChanged, .leftMouseDown, .scrollWheel]
        ) { [weak self] event in
            if event.type == .scrollWheel {
                if self?.scrollVisibleWindow(for: event) == true {
                    return nil
                }
                return event
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            self?.lastModifierFlags = modifiers
            if event.type == .leftMouseDown {
                self?.lastClickModifierFlags = modifiers
            }
            return event
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.flagsChanged, .leftMouseDown]
        ) { [weak self] event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            self?.lastModifierFlags = modifiers
            if event.type == .leftMouseDown {
                self?.lastClickModifierFlags = modifiers
            }
        }
    }

    private func removeModifierTracking() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
    }

    private func selectionModifiers() -> NSEvent.ModifierFlags {
        let currentEventFlags = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
        let liveFlags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return currentEventFlags
            .union(liveFlags)
            .union(lastClickModifierFlags)
            .union(lastModifierFlags)
    }

    private func scrollVisibleWindow(for event: NSEvent) -> Bool {
        let cappedCount = min(filteredClipItems().count, maxVisibleItems)
        let visibleCount = min(defaultVisibleItems, cappedCount)
        let maxStart = max(0, cappedCount - visibleCount)
        guard maxStart > 0 else {
            return false
        }

        let deltaY = event.scrollingDeltaY
        guard deltaY != 0 else {
            return false
        }

        let step = deltaY < 0 ? 1 : -1
        let nextStart = max(0, min(currentStartIndex + step, maxStart))
        guard nextStart != currentStartIndex else {
            return false
        }

        currentStartIndex = nextStart
        rebuildMenuContents()
        menuNeedsRebuild = false
        return true
    }

    private func rebuildMenuContents() {
        while menu.items.count > 2 {
            menu.removeItem(at: 2)
        }

        let filteredItems = filteredClipItems()
        let cappedItems = Array(filteredItems.prefix(maxVisibleItems))
        let totalItemsForMenu = cappedItems.count
        let visibleCount = min(defaultVisibleItems, totalItemsForMenu)
        let maxStartIndex = max(0, totalItemsForMenu - visibleCount)
        let startIndex = min(currentStartIndex, maxStartIndex)
        let endIndex = min(totalItemsForMenu, startIndex + visibleCount)
        currentStartIndex = startIndex

        if filteredItems.isEmpty {
            let emptyItem = NSMenuItem(title: "No clipboard items", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for item in cappedItems[startIndex..<endIndex] {
                menu.addItem(makeClipMenuItem(for: item, selectionAction: .copy))
                menu.addItem(
                    makeClipMenuItem(
                        for: item,
                        selectionAction: .pin,
                        alternateModifiers: [.option]
                    )
                )
                menu.addItem(
                    makeClipMenuItem(
                        for: item,
                        selectionAction: .delete,
                        alternateModifiers: [.option, .shift]
                    )
                )
            }

            if totalItemsForMenu > 0 {
                let statusItem = NSMenuItem(
                    title: "Showing \(startIndex + 1)-\(endIndex) of \(totalItemsForMenu)",
                    action: nil,
                    keyEquivalent: ""
                )
                statusItem.isEnabled = false
                menu.addItem(statusItem)
            }

        }

        let actionHintItem = NSMenuItem(
            title: "Click=Copy   ⌥Click=Pin   ⇧⌥Click=Delete",
            action: nil,
            keyEquivalent: ""
        )
        actionHintItem.isEnabled = false
        menu.addItem(actionHintItem)

        menu.addItem(.separator())

        let appearanceSettings = pinAppearanceSettingsProvider?() ?? .default
        let shadowItem = NSMenuItem(
            title: "Window Shadow",
            action: #selector(toggleWindowShadow(_:)),
            keyEquivalent: ""
        )
        shadowItem.target = self
        shadowItem.state = appearanceSettings.windowShadowEnabled ? .on : .off
        menu.addItem(shadowItem)

        let currentOpacityPercent = Int((appearanceSettings.defaultOpacity * 100).rounded())
        let opacityItem = NSMenuItem(
            title: "Default Opacity: \(currentOpacityPercent)%",
            action: nil,
            keyEquivalent: ""
        )
        opacityItem.submenu = makeOpacitySubmenu(currentPercent: currentOpacityPercent)
        menu.addItem(opacityItem)

        menu.addItem(.separator())

        let preferencesItem = NSMenuItem(
            title: "Preferences",
            action: nil,
            keyEquivalent: ""
        )
        preferencesItem.submenu = makePreferencesSubmenu()
        menu.addItem(preferencesItem)

        menu.addItem(.separator())

        let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearHistory(_:)), keyEquivalent: "")
        clearItem.target = self
        clearItem.isEnabled = !allItems.isEmpty
        clearItem.image = symbolImage(name: "trash", pointSize: 13)
        menu.addItem(clearItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = symbolImage(name: "power", pointSize: 13)
        menu.addItem(quitItem)
    }

    private func filteredClipItems() -> [ClipItem] {
        let query = searchField.stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !query.isEmpty else {
            return allItems
        }

        return allItems.filter { item in
            let haystack = [
                item.text ?? item.previewText,
                item.sourceAppName ?? "",
                item.previewText
            ]
            .joined(separator: "\n")
            .lowercased()

            return haystack.contains(query)
        }
    }

    private func makeClipMenuItem(
        for item: ClipItem,
        selectionAction: ClipSelectionAction,
        alternateModifiers: NSEvent.ModifierFlags? = nil
    ) -> NSMenuItem {
        let menuItem = NSMenuItem(
            title: "",
            action: #selector(clipItemSelected(_:)),
            keyEquivalent: ""
        )
        menuItem.target = self
        menuItem.representedObject = item.id.uuidString
        menuItem.tag = selectionAction.rawValue
        menuItem.toolTip = tooltipText(for: item)
        menuItem.image = iconImage(for: item)
        menuItem.attributedTitle = attributedTitle(for: item)
        if let alternateModifiers {
            menuItem.isAlternate = true
            menuItem.keyEquivalentModifierMask = alternateModifiers
        }
        return menuItem
    }

    private func titleForMenuItem(_ item: ClipItem) -> String {
        switch item.kind {
        case .text:
            guard let text = item.text, !text.isEmpty else {
                return "(empty text)"
            }
            let singleLine = text
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return truncate(singleLine, limit: 24)
        case .image:
            let width = Int(item.imagePixelWidth ?? 0)
            let height = Int(item.imagePixelHeight ?? 0)
            if width > 0 && height > 0 {
                return "Image \(width)×\(height)"
            }
            return "Image"
        }
    }

    private func tooltipText(for item: ClipItem) -> String {
        let source = item.sourceAppName.map { "Source: \($0)\n" } ?? ""
        switch item.kind {
        case .text:
            return source + (item.text ?? "")
        case .image:
            return source + item.previewText
        }
    }

    private func iconImage(for item: ClipItem) -> NSImage? {
        switch item.kind {
        case .text:
            return symbolImage(name: "doc.text", pointSize: 18)
        case .image:
            if let image = imageProvider?(item) {
                return ImageUtilities.menuThumbnail(for: image, canvasPointSize: 28)
            }
            return symbolImage(name: "photo", pointSize: 18)
        }
    }

    private func attributedTitle(for item: ClipItem) -> NSAttributedString {
        let title = titleForMenuItem(item)
        let subtitle = subtitleForMenuItem(item)

        let result = NSMutableAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )

        result.append(
            NSAttributedString(
                string: "\n\(subtitle)",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
        )

        return result
    }

    private func subtitleForMenuItem(_ item: ClipItem) -> String {
        let relativeTime = relativeDateFormatter.localizedString(for: item.createdAt, relativeTo: Date())
        if let source = item.sourceAppName, !source.isEmpty {
            return "\(source) • \(relativeTime)"
        }
        return relativeTime
    }

    private func symbolImage(name: String, pointSize: CGFloat) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
    }

    private func makeOpacitySubmenu(currentPercent: Int) -> NSMenu {
        let submenu = NSMenu()
        let nearest = opacityPercentOptions.min {
            abs($0 - currentPercent) < abs($1 - currentPercent)
        } ?? 60

        for percent in opacityPercentOptions {
            let item = NSMenuItem(
                title: "\(percent)%",
                action: #selector(setDefaultOpacity(_:)),
                keyEquivalent: ""
            )
            item.tag = percent
            item.target = self
            item.state = (percent == nearest) ? .on : .off
            submenu.addItem(item)
        }

        return submenu
    }

    private func makeManualHotKeySubmenu(
        current: HotKeyShortcut,
        manualAction: Selector
    ) -> NSMenu {
        let submenu = NSMenu()

        let currentItem = NSMenuItem(
            title: "Current: \(current.displayString)",
            action: nil,
            keyEquivalent: ""
        )
        currentItem.isEnabled = false
        submenu.addItem(currentItem)

        submenu.addItem(.separator())
        let manualItem = NSMenuItem(
            title: "Set Manually…",
            action: manualAction,
            keyEquivalent: ""
        )
        manualItem.target = self
        submenu.addItem(manualItem)
        return submenu
    }

    private func makeStorageLocationSubmenu(
        current: URL?,
        defaultLocation: URL?
    ) -> NSMenu {
        let submenu = NSMenu()

        let currentTitle: String
        if let current {
            currentTitle = "Current: \(abbreviatedPath(for: current))"
        } else {
            currentTitle = "Current: unavailable"
        }
        let currentItem = NSMenuItem(title: currentTitle, action: nil, keyEquivalent: "")
        currentItem.isEnabled = false
        submenu.addItem(currentItem)

        submenu.addItem(.separator())

        let chooseItem = NSMenuItem(
            title: "Choose Folder…",
            action: #selector(chooseStorageLocation(_:)),
            keyEquivalent: ""
        )
        chooseItem.target = self
        submenu.addItem(chooseItem)

        let useDefaultItem = NSMenuItem(
            title: "Use Default Location",
            action: #selector(resetStorageLocation(_:)),
            keyEquivalent: ""
        )
        useDefaultItem.target = self
        if let current, let defaultLocation {
            useDefaultItem.isEnabled = current.standardizedFileURL != defaultLocation.standardizedFileURL
        } else {
            useDefaultItem.isEnabled = false
        }
        submenu.addItem(useDefaultItem)

        if let defaultLocation {
            let defaultItem = NSMenuItem(
                title: "Default: \(abbreviatedPath(for: defaultLocation))",
                action: nil,
                keyEquivalent: ""
            )
            defaultItem.isEnabled = false
            submenu.addItem(defaultItem)
        }

        return submenu
    }

    private func makePreferencesSubmenu() -> NSMenu {
        let submenu = NSMenu()

        let quickPasteShortcut = quickPasteHotKeyProvider?() ?? .quickPasteDefault
        let quickPasteHotKeyItem = NSMenuItem(
            title: "Quick Paste Hotkey: \(quickPasteShortcut.displayString)",
            action: nil,
            keyEquivalent: ""
        )
        quickPasteHotKeyItem.submenu = makeManualHotKeySubmenu(
            current: quickPasteShortcut,
            manualAction: #selector(setQuickPasteHotKeyManually(_:))
        )
        submenu.addItem(quickPasteHotKeyItem)

        submenu.addItem(.separator())

        let screenshotShortcut = screenshotHotKeyProvider?() ?? .screenshotDefault
        let screenshotHotKeyItem = NSMenuItem(
            title: "Screenshot Hotkey: \(screenshotShortcut.displayString)",
            action: nil,
            keyEquivalent: ""
        )
        screenshotHotKeyItem.submenu = makeManualHotKeySubmenu(
            current: screenshotShortcut,
            manualAction: #selector(setScreenshotHotKeyManually(_:))
        )
        submenu.addItem(screenshotHotKeyItem)

        let screenshotHintItem = NSMenuItem(
            title: "Action: region screenshot to clipboard",
            action: nil,
            keyEquivalent: ""
        )
        screenshotHintItem.isEnabled = false
        submenu.addItem(screenshotHintItem)

        submenu.addItem(.separator())

        let currentStorage = storageLocationProvider?() ?? defaultStorageLocationProvider?()
        let defaultStorage = defaultStorageLocationProvider?()
        let storageItem = NSMenuItem(
            title: "Storage Location",
            action: nil,
            keyEquivalent: ""
        )
        storageItem.submenu = makeStorageLocationSubmenu(
            current: currentStorage,
            defaultLocation: defaultStorage
        )
        submenu.addItem(storageItem)

        submenu.addItem(.separator())

        let launchAtLoginEnabled = launchAtLoginEnabledProvider?() ?? false
        let launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.state = launchAtLoginEnabled ? .on : .off
        submenu.addItem(launchAtLoginItem)

        return submenu
    }

    private func abbreviatedPath(for url: URL) -> String {
        let path = url.path
        let homePath = NSHomeDirectory()
        if path.hasPrefix(homePath) {
            return "~" + path.dropFirst(homePath.count)
        }
        return path
    }

    private func clipItem(for menuItem: NSMenuItem) -> ClipItem? {
        guard let uuidString = menuItem.representedObject as? String,
              let id = UUID(uuidString: uuidString)
        else {
            return nil
        }
        return allItems.first { $0.id == id }
    }

    private func truncate(_ text: String, limit: Int) -> String {
        guard text.count > limit else {
            return text
        }
        return String(text.prefix(limit - 1)) + "…"
    }

    @objc
    private func clipItemSelected(_ sender: NSMenuItem) {
        guard let item = clipItem(for: sender) else {
            NSSound.beep()
            return
        }

        let explicitAction = ClipSelectionAction(rawValue: sender.tag) ?? .copy
        switch explicitAction {
        case .pin:
            onPinRequest?(item)
            return
        case .delete:
            onDeleteRequest?(item)
            return
        case .copy:
            break
        }

        let modifiers = selectionModifiers()
        let optionPressed = modifiers.contains(.option)
        let shiftPressed = modifiers.contains(.shift)

        if optionPressed && shiftPressed {
            onDeleteRequest?(item)
            return
        }

        if optionPressed {
            onPinRequest?(item)
            return
        }

        onCopyRequest?(item)
    }

    @objc
    private func toggleWindowShadow(_ sender: NSMenuItem) {
        let current = pinAppearanceSettingsProvider?().windowShadowEnabled ?? PinAppearanceSettings.default.windowShadowEnabled
        onWindowShadowChanged?(!current)
        rebuildMenuContents()
    }

    @objc
    private func setDefaultOpacity(_ sender: NSMenuItem) {
        let opacity = CGFloat(sender.tag) / 100.0
        onDefaultOpacityChanged?(opacity)
        rebuildMenuContents()
    }

    @objc
    private func setQuickPasteHotKeyManually(_ sender: Any?) {
        onQuickPasteHotKeyManualRequest?()
        rebuildMenuContents()
    }

    @objc
    private func setScreenshotHotKeyManually(_ sender: Any?) {
        onScreenshotHotKeyManualRequest?()
        rebuildMenuContents()
    }

    @objc
    private func chooseStorageLocation(_ sender: Any?) {
        onStorageLocationRequest?()
    }

    @objc
    private func resetStorageLocation(_ sender: Any?) {
        onResetStorageLocationRequest?()
        rebuildMenuContents()
    }

    @objc
    private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let current = launchAtLoginEnabledProvider?() ?? false
        onLaunchAtLoginChanged?(!current)
        rebuildMenuContents()
    }

    @objc
    private func clearHistory(_ sender: Any?) {
        guard !allItems.isEmpty else {
            NSSound.beep()
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Clear Clipboard History?"
        alert.informativeText = "This removes all saved text and image entries."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            onClearRequest?()
        }
    }

    @objc
    private func quit(_ sender: Any?) {
        onQuitRequest?()
    }
}
