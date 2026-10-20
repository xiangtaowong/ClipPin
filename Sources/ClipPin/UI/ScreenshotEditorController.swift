import AppKit
import UniformTypeIdentifiers

final class ScreenshotEditorController: NSWindowController, NSWindowDelegate {
    private let screenshotDocument: ScreenshotDocument
    private let canvas: ScreenshotCanvas
    private let scroll = NSScrollView()
    private let colors = NSColorWell()
    private let widthSlider = NSSlider(value: 4, minValue: 1, maxValue: 20, target: nil, action: nil)
    private let zoomLabel = NSTextField(labelWithString: "100%")
    private var undoButton: NSButton!
    private var redoButton: NSButton!
    private var tools: NSSegmentedControl!
    private var cropButton: NSButton!
    private var cropRow: NSStackView!
    private var applyCropButton: NSButton!
    private let cropLabel = NSTextField(labelWithString: "Drag to select a crop")
    private var copyButton: NSButton!
    private var saveButton: NSButton!
    private var completion: ((Data?) -> Void)?
    private var keyMonitor: Any?
    private var zoom: CGFloat = 1

    init?(data: Data, completion: @escaping (Data?) -> Void) {
        guard let screenshotDocument = ScreenshotDocument(data: data) else { return nil }
        self.screenshotDocument = screenshotDocument
        self.canvas = ScreenshotCanvas(document: screenshotDocument)
        self.completion = completion
        let available = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1200, height: 800)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: min(1000, available.width - 40),
                                                 height: min(740, available.height - 60)),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Edit Screenshot"
        window.isReleasedWhenClosed = false
        window.contentMinSize = CGSize(width: 680, height: 360)
        super.init(window: window)
        window.delegate = self
        buildInterface()
        window.center()
        canvas.onChange = { [weak self] in self?.refresh() }
        canvas.onCropChange = { [weak self] in self?.refreshCropControls() }
        canvas.onZoom = { [weak self] factor in
            guard let self else { return }
            self.setZoom(self.zoom * factor)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { if let keyMonitor { NSEvent.removeMonitor(keyMonitor) } }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.contentView?.layoutSubtreeIfNeeded()
        fit(nil)
        window?.makeFirstResponder(canvas)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window,
                  self.window?.attachedSheet == nil else { return event }
            let key = event.charactersIgnoringModifiers?.lowercased()
            if event.keyCode == 53 {
                self.canvas.isCropping ? self.cancelCrop(nil) : self.cancel(nil)
                return nil
            }
            if self.canvas.isCropping && [36, 76].contains(event.keyCode) {
                self.applyCrop(nil)
                return nil
            }
            guard event.modifierFlags.contains(.command) else { return event }
            switch key {
            case "z":
                event.modifierFlags.contains(.shift) ? self.redo(nil) : self.undo(nil)
            case "s": self.save(nil)
            case "c": self.copy(nil)
            case "=", "+": self.zoomIn(nil)
            case "-": self.zoomOut(nil)
            case "0": self.fit(nil)
            default: return event
            }
            return nil
        }
    }

    private func buildInterface() {
        guard let root = window?.contentView else { return }
        tools = NSSegmentedControl(labels: ScreenshotTool.allCases.map(\.rawValue),
            trackingMode: .selectOne, target: self, action: #selector(selectTool(_:)))
        tools.selectedSegment = 0
        tools.setAccessibilityLabel("Annotation tool")
        cropButton = button("Crop", #selector(toggleCrop(_:)))
        cropButton.setButtonType(.toggle)
        cropButton.toolTip = "Select, move and resize a crop. Enter to apply, Esc to cancel."
        let toolRow = row([tools, cropButton])
        applyCropButton = button("Apply Crop", #selector(applyCrop(_:)))
        cropLabel.font = .systemFont(ofSize: 11)
        cropRow = row([cropLabel, applyCropButton, button("Cancel Crop", #selector(cancelCrop(_:)))])
        cropRow.isHidden = true

        colors.color = .systemRed
        colors.target = self
        colors.action = #selector(changeColor(_:))
        colors.setAccessibilityLabel("Custom annotation color")
        colors.widthAnchor.constraint(equalToConstant: 44).isActive = true
        let palette = NSPopUpButton()
        palette.addItems(withTitles: ["Red", "Orange", "Yellow", "Green", "Blue", "Black", "White"])
        palette.target = self
        palette.action = #selector(selectColor(_:))
        palette.setAccessibilityLabel("Color presets")
        widthSlider.target = self
        widthSlider.action = #selector(changeWidth(_:))
        widthSlider.widthAnchor.constraint(equalToConstant: 95).isActive = true
        widthSlider.setAccessibilityLabel("Stroke width and text size")
        undoButton = button("Undo", #selector(undo(_:)))
        redoButton = button("Redo", #selector(redo(_:)))
        let styleRow = row([palette, colors, NSTextField(labelWithString: "Size"), widthSlider,
                            undoButton, redoButton, button("Clear", #selector(clear(_:)))])
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = .underPageBackgroundColor
        scroll.documentView = canvas

        let hint = NSTextField(labelWithString: "Scroll to pan · Pinch to zoom · Text: click to add")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        copyButton = button("Copy & Close", #selector(copy(_:)))
        copyButton.keyEquivalent = "\r"
        saveButton = button("Save PNG…", #selector(save(_:)))
        let actions = row([button("−", #selector(zoomOut(_:))), zoomLabel,
                           button("+", #selector(zoomIn(_:))), button("Fit", #selector(fit(_:))),
                           NSView(), button("Cancel", #selector(cancel(_:))),
                           saveButton, copyButton])
        let stack = NSStackView(views: [toolRow, styleRow, cropRow, scroll, hint, actions])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            actions.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        scroll.setContentHuggingPriority(.defaultLow, for: .vertical)
        refresh()
    }

    private func row(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        return stack
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        NSButton(title: title, target: self, action: action)
    }

    @objc private func selectTool(_ sender: NSSegmentedControl) {
        let selected = sender.selectedSegment
        cancelCrop(nil)
        canvas.tool = ScreenshotTool.allCases[selected]
        tools.selectedSegment = selected
        window?.makeFirstResponder(canvas)
    }

    @objc private func selectColor(_ sender: NSPopUpButton) {
        let palette: [NSColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .black, .white]
        colors.color = palette[sender.indexOfSelectedItem]
        changeColor(colors)
    }

    @objc private func changeColor(_ sender: NSColorWell) { canvas.color = sender.color }
    @objc private func changeWidth(_ sender: NSSlider) { canvas.strokeWidth = CGFloat(sender.doubleValue) }
    @objc private func undo(_ sender: Any?) { cancelCrop(nil); canvas.discardDraft(); screenshotDocument.undo(); refresh() }
    @objc private func redo(_ sender: Any?) { cancelCrop(nil); canvas.discardDraft(); screenshotDocument.redo(); refresh() }
    @objc private func clear(_ sender: Any?) { cancelCrop(nil); canvas.discardDraft(); screenshotDocument.clear(); refresh() }

    @objc private func toggleCrop(_ sender: Any?) {
        if canvas.isCropping { cancelCrop(nil); return }
        canvas.beginCrop()
        tools.selectedSegment = -1
        window?.makeFirstResponder(canvas)
    }

    @objc private func applyCrop(_ sender: Any?) {
        guard canvas.applyCrop() else { NSSound.beep(); return }
        tools.selectedSegment = ScreenshotTool.allCases.firstIndex(of: canvas.tool) ?? 0
        window?.contentView?.layoutSubtreeIfNeeded()
        fit(nil)
        window?.makeFirstResponder(canvas)
    }

    @objc private func cancelCrop(_ sender: Any?) {
        canvas.cancelCrop()
        tools.selectedSegment = ScreenshotTool.allCases.firstIndex(of: canvas.tool) ?? 0
    }

    private func refreshCropControls() {
        cropRow.isHidden = !canvas.isCropping
        cropButton.state = canvas.isCropping ? .on : .off
        copyButton.isEnabled = !canvas.isCropping
        saveButton.isEnabled = !canvas.isCropping
        let rect = canvas.cropSelection.rect.flatMap {
            ScreenshotCropSelection.pixelRect($0, in: screenshotDocument.size)
        }
        applyCropButton.isEnabled = rect != nil
        if let rect {
            cropLabel.stringValue = "\(Int(rect.width)) × \(Int(rect.height)) px · Drag handles or move inside"
        } else {
            cropLabel.stringValue = "Drag to select · Enter applies · Esc cancels"
        }
    }
    @objc private func zoomIn(_ sender: Any?) { setZoom(zoom * 1.25) }
    @objc private func zoomOut(_ sender: Any?) { setZoom(zoom / 1.25) }
    @objc private func fit(_ sender: Any?) {
        let size = scroll.contentSize
        setZoom(min(1, min(size.width / screenshotDocument.size.width, size.height / screenshotDocument.size.height)))
    }

    private func setZoom(_ value: CGFloat) {
        let visible = scroll.contentView.bounds
        let center = CGPoint(x: visible.midX / zoom, y: visible.midY / zoom)
        zoom = min(8, max(0.02, value))
        canvas.scale = zoom
        canvas.setFrameSize(CGSize(width: screenshotDocument.size.width * zoom, height: screenshotDocument.size.height * zoom))
        scroll.contentView.scroll(to: CGPoint(x: max(0, center.x * zoom - visible.width / 2),
                                              y: max(0, center.y * zoom - visible.height / 2)))
        scroll.reflectScrolledClipView(scroll.contentView)
        zoomLabel.stringValue = "\(Int((zoom * 100).rounded()))%"
        canvas.needsDisplay = true
    }

    private func refresh() {
        let size = screenshotDocument.size
        if canvas.frame.size != CGSize(width: size.width * zoom, height: size.height * zoom) { fit(nil) }
        canvas.needsDisplay = true
        undoButton.isEnabled = screenshotDocument.canUndo
        redoButton.isEnabled = screenshotDocument.canRedo
    }

    @objc private func copy(_ sender: Any?) {
        guard !canvas.isCropping else { NSSound.beep(); return }
        guard let data = screenshotDocument.pngData() else { showExportError(); return }
        finish(data)
        close()
    }

    @objc private func save(_ sender: Any?) {
        guard !canvas.isCropping else { NSSound.beep(); return }
        guard let window else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "ClipPin-Screenshot.png"
        panel.beginSheetModal(for: window) { [weak self] result in
            guard let self, result == .OK, let url = panel.url else { return }
            guard let data = self.screenshotDocument.pngData() else { self.showExportError(); return }
            do { try data.write(to: url, options: .atomic) }
            catch { self.showExportError(error.localizedDescription) }
        }
    }

    private func showExportError(_ message: String = "Unable to render the screenshot. Please try again.") {
        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = "Unable to Save Screenshot"
        alert.informativeText = message
        alert.beginSheetModal(for: window)
    }

    @objc private func cancel(_ sender: Any?) { close() }
    func windowWillClose(_ notification: Notification) { finish(nil) }

    private func finish(_ data: Data?) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
        colors.deactivate()
        let callback = completion
        completion = nil
        callback?(data)
    }
}

final class ScreenshotCanvas: NSView {
    let document: ScreenshotDocument
    var tool: ScreenshotTool = .draw
    var color: NSColor = .systemRed
    var strokeWidth: CGFloat = 4
    var scale: CGFloat = 1
    var onChange: (() -> Void)?
    var onZoom: ((CGFloat) -> Void)?
    var onCropChange: (() -> Void)?
    private(set) var isCropping = false
    private(set) var cropSelection = ScreenshotCropSelection()
    private var draft: ScreenshotAnnotation?

    init(document: ScreenshotDocument) {
        self.document = document
        super.init(frame: NSRect(origin: .zero, size: document.size))
        setAccessibilityLabel("Screenshot annotation canvas")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var acceptsFirstResponder: Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        document.draw(in: context, draft: draft)
        if isCropping { drawCropOverlay() }
        context.restoreGState()
    }

    private func localImagePoint(_ event: NSEvent) -> CGPoint {
        let point = convert(event.locationInWindow, from: nil)
        return CGPoint(x: min(document.size.width, max(0, point.x / scale)),
                       y: min(document.size.height, max(0, point.y / scale)))
    }

    private func imagePoint(_ event: NSEvent) -> CGPoint {
        let point = localImagePoint(event)
        return CGPoint(x: point.x + document.cropRect.minX, y: point.y + document.cropRect.minY)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if isCropping {
            cropSelection.begin(at: localImagePoint(event), in: document.size, tolerance: 9 / scale)
            cropDidChange()
            return
        }
        let point = imagePoint(event)
        if tool == .text {
            addText(at: point)
        } else {
            draft = ScreenshotAnnotation(tool: tool, points: [point], color: color, width: strokeWidth)
            needsDisplay = true
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if isCropping {
            cropSelection.drag(to: localImagePoint(event), in: document.size)
            autoscroll(with: event)
            cropDidChange()
            return
        }
        guard var annotation = draft else { return }
        let point = imagePoint(event)
        if annotation.tool == .draw || annotation.tool == .highlight {
            annotation.points.append(point)
        } else {
            annotation.points = [annotation.points[0], point]
        }
        draft = annotation
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if isCropping {
            cropSelection.drag(to: localImagePoint(event), in: document.size)
            cropSelection.end()
            cropDidChange()
            return
        }
        guard draft != nil else { return }
        // Keep a click as a single dot; include the final coordinate after a drag.
        if draft!.points.count > 1 { mouseDragged(with: event) }
        if let draft { document.add(draft) }
        discardDraft()
        onChange?()
    }

    func discardDraft() { draft = nil; needsDisplay = true }
    override func magnify(with event: NSEvent) { onZoom?(1 + event.magnification) }

    func beginCrop() {
        discardDraft()
        cropSelection = ScreenshotCropSelection()
        isCropping = true
        cropDidChange()
    }

    func cancelCrop() {
        isCropping = false
        cropSelection = ScreenshotCropSelection()
        cropDidChange()
    }

    @discardableResult
    func applyCrop() -> Bool {
        guard isCropping, let rect = cropSelection.rect,
              ScreenshotCropSelection.pixelRect(rect, in: document.size) != nil else { return false }
        document.crop(to: rect)
        cancelCrop()
        onChange?()
        return true
    }

    private func cropDidChange() { needsDisplay = true; onCropChange?() }

    private func drawCropOverlay() {
        let overlay = NSBezierPath(rect: NSRect(origin: .zero, size: document.size))
        if let rect = cropSelection.rect { overlay.appendRect(rect) }
        overlay.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.45).setFill()
        overlay.fill()
        guard let rect = cropSelection.rect else { return }
        NSColor.systemBlue.setStroke()
        let border = NSBezierPath(rect: rect)
        border.lineWidth = 1.5 / scale
        border.stroke()
        for point in cropSelection.handles {
            let handle = NSBezierPath(rect: NSRect(x: point.x - 4 / scale, y: point.y - 4 / scale,
                                                   width: 8 / scale, height: 8 / scale))
            NSColor.white.setFill()
            handle.fill()
            handle.lineWidth = 1 / scale
            handle.stroke()
        }
    }

    private func addText(at point: CGPoint) {
        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = "Add Text"
        alert.informativeText = "Text uses the selected color and size."
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 64))
        field.placeholderString = "Enter annotation…"
        field.maximumNumberOfLines = 0
        field.cell?.wraps = true
        field.cell?.isScrollable = false
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        let color = self.color, width = strokeWidth
        alert.beginSheetModal(for: window) { [weak self] result in
            guard let self, result == .alertFirstButtonReturn,
                  !field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            self.document.add(ScreenshotAnnotation(tool: .text, points: [point], color: color,
                width: width, text: field.stringValue))
            self.onChange?()
            window.makeFirstResponder(self)
        }
    }
}
