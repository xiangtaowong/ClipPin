import AppKit

@MainActor
final class PinnedLivePanelController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?
    var onPauseRequest: (() -> Void)?
    private let liveView = LivePinView()
    private let scrollView = NSScrollView()
    private let statusLabel = NSTextField(wrappingLabelWithString: "Starting Live Pin…")
    private let pauseItem = NSMenuItem(title: "Pause Live Pin", action: nil, keyEquivalent: "")
    private let cropItem = NSMenuItem(title: "Crop Region…", action: nil, keyEquivalent: "")
    private let resetItem = NSMenuItem(title: "Show Whole Window", action: nil, keyEquivalent: "")
    private let actualSizeItem = NSMenuItem(title: "Actual Size (100%)", action: nil, keyEquivalent: "")
    private let opacityItem = NSMenuItem(title: "Opacity: 100%", action: nil, keyEquivalent: "")
    private var statusTimer: Timer?
    private var statusMessage: String?
    private var didReceiveFrame = false

    init(sourceSize: CGSize) {
        let panel = LivePinPanel(
            contentRect: NSRect(origin: .zero, size: Self.initialSize(for: sourceSize)),
            styleMask: [.borderless, .resizable, .nonactivatingPanel], backing: .buffered, defer: false
        )
        panel.title = "ClipPin Live Pin"
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = true
        panel.backgroundColor = .black
        panel.contentMinSize = NSSize(width: 80, height: 64)
        super.init(window: panel)
        panel.delegate = self
        let container = LivePinResizeView(frame: CGRect(origin: .zero, size: panel.contentLayoutRect.size))
        panel.contentView = container
        scrollView.frame = container.bounds.insetBy(dx: LivePinResizeView.borderWidth, dy: LivePinResizeView.borderWidth)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .black
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.contentView = PixelAlignedClipView()
        scrollView.contentView.drawsBackground = true
        scrollView.contentView.backgroundColor = .black
        scrollView.documentView = liveView
        container.addSubview(scrollView)
        setupMenu()
        container.menu = liveView.menu
        scrollView.menu = liveView.menu
        setupStatusLabel()
        liveView.onCropChanged = { [weak self] _ in
            self?.showOriginalSize()
            self?.resetItem.isEnabled = self?.liveView.isCropped ?? false
        }
        liveView.onCropModeChanged = { [weak self] cropping in
            self?.updateStatusLabel(cropping: cropping)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func applyAppearance(settings: PinAppearanceSettings) {
        window?.hasShadow = settings.windowShadowEnabled
        // Live text starts opaque; clipboard pins keep their saved default.
        window?.alphaValue = 1
    }

    func setFrame(_ frame: LivePinFrame) {
        liveView.setFrame(frame)
        if !didReceiveFrame {
            didReceiveFrame = true
            showOriginalSize()
        }
        cropItem.isEnabled = true
        actualSizeItem.isEnabled = true
    }

    func setPauseState(paused: Bool, enabled: Bool) {
        pauseItem.title = paused ? "Resume Live Pin" : "Pause Live Pin"
        pauseItem.isEnabled = enabled
    }

    func showStatus(_ message: String?, temporary: Bool = false) {
        statusTimer?.invalidate()
        statusTimer = nil
        statusMessage = message
        updateStatusLabel(cropping: liveView.isCropping)
        if temporary {
            statusTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.showStatus(nil) }
            }
        }
    }

    func showErrorDetails(_ message: String) {
        liveView.toolTip = message
    }

    func windowWillClose(_ notification: Notification) {
        statusTimer?.invalidate()
        liveView.clearImage()
        onClose?()
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        cropItem.action = #selector(cropRegion(_:))
        cropItem.target = self
        cropItem.isEnabled = false
        menu.addItem(cropItem)
        resetItem.action = #selector(resetCrop(_:))
        resetItem.target = self
        resetItem.isEnabled = false
        menu.addItem(resetItem)
        actualSizeItem.action = #selector(showActualSize(_:))
        actualSizeItem.target = self
        actualSizeItem.isEnabled = false
        actualSizeItem.toolTip = "Match the original window's text size. Drag the border to resize and drag the image to pan."
        menu.addItem(actualSizeItem)
        opacityItem.submenu = makeOpacityMenu()
        menu.addItem(opacityItem)
        pauseItem.action = #selector(togglePause(_:))
        pauseItem.target = self
        pauseItem.isEnabled = false
        menu.addItem(pauseItem)
        menu.addItem(.separator())
        let close = NSMenuItem(title: "Close Live Pin", action: #selector(closePin(_:)), keyEquivalent: "")
        close.target = self
        menu.addItem(close)
        liveView.menu = menu
    }

    private func makeOpacityMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let current = Int(((window?.alphaValue ?? 1) * 100).rounded())
        for percent in [30, 40, 50, 60, 70, 80, 90, 100] {
            let item = NSMenuItem(title: "\(percent)%", action: #selector(setOpacity(_:)), keyEquivalent: "")
            item.tag = percent
            item.target = self
            item.state = percent == current ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    private func setupStatusLabel() {
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .white
        statusLabel.backgroundColor = NSColor.black.withAlphaComponent(0.8)
        statusLabel.drawsBackground = true
        statusLabel.isSelectable = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        guard let container = window?.contentView else { return }
        container.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8),
            statusLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
    }

    private func updateStatusLabel(cropping: Bool) {
        let message = cropping ? "Drag to select a region · Esc to cancel" : statusMessage
        statusLabel.stringValue = message ?? ""
        statusLabel.isHidden = message == nil
    }

    private func showOriginalSize() {
        guard let window, let original = liveView.displayedPointSize else { return }
        let screen = window.screen ?? NSScreen.main
        let border = 2 * LivePinResizeView.borderWidth
        let available = screen?.visibleFrame ?? CGRect(origin: .zero, size: original)
        let size = CGSize(width: min(original.width + border, available.width),
                          height: min(original.height + border, available.height))
        let top = window.frame.maxY
        window.setContentSize(size)
        window.setFrameOrigin(NSPoint(
            x: max(available.minX, min(window.frame.minX, available.maxX - window.frame.width)),
            y: max(available.minY, min(top - window.frame.height, available.maxY - window.frame.height))))
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private static func initialSize(for size: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return CGSize(width: 520, height: 320) }
        let available = NSScreen.main?.visibleFrame.size ?? size
        let border = 2 * LivePinResizeView.borderWidth
        return CGSize(width: max(80, min(size.width + border, available.width)),
                      height: max(64, min(size.height + border, available.height)))
    }

    @objc private func cropRegion(_ sender: Any?) {
        // Start from the whole source for a new crop, rather than requiring
        // successive crops to find pixels outside the previous selection.
        liveView.beginCropping(showWholeWindow: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(liveView)
    }
    @objc private func resetCrop(_ sender: Any?) { liveView.resetCrop() }
    @objc private func showActualSize(_ sender: Any?) {
        showOriginalSize()
    }
    func windowDidChangeBackingProperties(_ notification: Notification) { liveView.updateNativeSize() }
    @objc private func setOpacity(_ sender: NSMenuItem) {
        window?.alphaValue = CGFloat(sender.tag) / 100
        opacityItem.title = "Opacity: \(sender.tag)%"
        opacityItem.submenu = makeOpacityMenu()
    }
    @objc private func togglePause(_ sender: Any?) { onPauseRequest?() }
    @objc private func closePin(_ sender: Any?) { window?.close() }
}

private final class LivePinPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Borderless panels do not reliably expose AppKit's standard resize edges.
/// Keep a small border outside the captured content with explicit hit targets.
@MainActor
private final class LivePinResizeView: NSView {
    static let borderWidth: CGFloat = 6
    private struct Edges: OptionSet {
        let rawValue: Int
        static let left = Edges(rawValue: 1)
        static let right = Edges(rawValue: 2)
        static let bottom = Edges(rawValue: 4)
        static let top = Edges(rawValue: 8)
    }
    private var resizingEdges: Edges = []
    private var initialFrame = CGRect.zero
    private var initialMouse = CGPoint.zero
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        if bounds.contains(local), !edges(at: local).isEmpty { return self }
        return super.hitTest(point)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        bounds.fill()
        NSColor.gray.withAlphaComponent(0.65).setStroke()
        NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)).stroke()
        let grip = NSBezierPath()
        for offset: CGFloat in [3, 6, 9] {
            grip.move(to: CGPoint(x: bounds.maxX - offset - 2, y: bounds.minY + 2))
            grip.line(to: CGPoint(x: bounds.maxX - 2, y: bounds.minY + offset + 2))
        }
        grip.stroke()
    }

    override func resetCursorRects() {
        let b = Self.borderWidth
        let targets: [(CGRect, Edges)] = [
            (CGRect(x: 0, y: b, width: b, height: max(0, bounds.height - 2*b)), .left),
            (CGRect(x: bounds.maxX-b, y: b, width: b, height: max(0, bounds.height - 2*b)), .right),
            (CGRect(x: b, y: 0, width: max(0, bounds.width - 2*b), height: b), .bottom),
            (CGRect(x: b, y: bounds.maxY-b, width: max(0, bounds.width - 2*b), height: b), .top),
            (CGRect(x: 0, y: 0, width: b, height: b), [.left, .bottom]),
            (CGRect(x: bounds.maxX-b, y: 0, width: b, height: b), [.right, .bottom]),
            (CGRect(x: 0, y: bounds.maxY-b, width: b, height: b), [.left, .top]),
            (CGRect(x: bounds.maxX-b, y: bounds.maxY-b, width: b, height: b), [.right, .top])
        ]
        for (rect, edge) in targets { addCursorRect(rect, cursor: cursor(for: edge)) }
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        if event.modifierFlags.contains(.command) {
            window.performDrag(with: event)
            return
        }
        resizingEdges = edges(at: convert(event.locationInWindow, from: nil))
        initialFrame = window.frame
        initialMouse = window.convertPoint(toScreen: event.locationInWindow)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, !resizingEdges.isEmpty else { return }
        let mouse = window.convertPoint(toScreen: event.locationInWindow)
        let dx = mouse.x - initialMouse.x
        let dy = mouse.y - initialMouse.y
        var frame = initialFrame
        let minimum = window.contentMinSize
        if resizingEdges.contains(.left) {
            frame.size.width = max(minimum.width, initialFrame.width - dx)
            frame.origin.x = initialFrame.maxX - frame.width
        } else if resizingEdges.contains(.right) {
            frame.size.width = max(minimum.width, initialFrame.width + dx)
        }
        if resizingEdges.contains(.bottom) {
            frame.size.height = max(minimum.height, initialFrame.height - dy)
            frame.origin.y = initialFrame.maxY - frame.height
        } else if resizingEdges.contains(.top) {
            frame.size.height = max(minimum.height, initialFrame.height + dy)
        }
        window.setFrame(frame, display: true)
    }

    override func mouseUp(with event: NSEvent) { resizingEdges = [] }

    private func edges(at point: CGPoint) -> Edges {
        var result: Edges = []
        let b = Self.borderWidth
        if point.x < bounds.minX+b { result.insert(.left) }
        if point.x >= bounds.maxX-b { result.insert(.right) }
        if point.y < bounds.minY+b { result.insert(.bottom) }
        if point.y >= bounds.maxY-b { result.insert(.top) }
        return result
    }

    private func cursor(for edges: Edges) -> NSCursor {
        if #available(macOS 15.0, *) {
            let position: NSCursor.FrameResizePosition
            switch edges {
            case [.left, .top]: position = .topLeft
            case [.right, .top]: position = .topRight
            case [.left, .bottom]: position = .bottomLeft
            case [.right, .bottom]: position = .bottomRight
            case .left: position = .left
            case .right: position = .right
            case .top: position = .top
            default: position = .bottom
            }
            return .frameResize(position: position, directions: .all)
        }
        return edges.contains(.left) || edges.contains(.right) ? .resizeLeftRight : .resizeUpDown
    }
}

/// Fractional clip origins would interpolate an otherwise native pixel image.
private final class PixelAlignedClipView: NSClipView {
    override func scroll(to newOrigin: NSPoint) { super.scroll(to: aligned(newOrigin)) }
    override func setBoundsOrigin(_ newOrigin: NSPoint) { super.setBoundsOrigin(aligned(newOrigin)) }

    private func aligned(_ origin: NSPoint) -> NSPoint {
        let scale = window?.backingScaleFactor ?? 1
        return NSPoint(x: (origin.x * scale).rounded() / scale,
                       y: (origin.y * scale).rounded() / scale)
    }

    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var result = super.constrainBoundsRect(proposedBounds)
        result.origin = aligned(result.origin)
        return result
    }
}

/// The view uses top-left coordinates for both selection and CGImage cropping.
@MainActor
private final class LivePinView: NSView {
    var onCropChanged: ((CGSize) -> Void)?
    var onCropModeChanged: ((Bool) -> Void)?
    private var sourceImage: CGImage?
    private var displayedImage: CGImage?
    private var sourcePointSize = CGSize.zero
    private var panStart: CGPoint?
    private var panOrigin = CGPoint.zero
    private var crop = LivePinGeometry.fullCrop
    private var selectionStart: CGPoint?
    private var selectionEnd: CGPoint?
    private var selectionImageRect: CGRect?
    private var cropBeforeSelection: CGRect?
    private(set) var isCropping = false
    var isCropped: Bool { crop != LivePinGeometry.fullCrop }
    var displayedPointSize: CGSize? {
        guard let image = displayedImage else { return nil }
        guard let sourceImage else { return nil }
        return LivePinGeometry.croppedPointSize(
            pixelSize: CGSize(width: image.width, height: image.height),
            sourcePixelSize: CGSize(width: sourceImage.width, height: sourceImage.height),
            sourcePointSize: sourcePointSize)
    }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func setFrame(_ frame: LivePinFrame) {
        sourceImage = frame.image
        sourcePointSize = frame.pointSize
        updateDisplayedImage()
    }

    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); updateNativeSize() }

    func updateNativeSize() {
        if let size = displayedPointSize { setFrameSize(size) }
        needsDisplay = true
    }

    func clearImage() {
        finishPanning()
        sourceImage = nil
        displayedImage = nil
    }

    func beginCropping(showWholeWindow: Bool = false) {
        guard sourceImage != nil else { return }
        cropBeforeSelection = crop
        if showWholeWindow {
            crop = LivePinGeometry.fullCrop
            updateDisplayedImage()
            if let size = displayedPointSize { onCropChanged?(size) }
        }
        isCropping = true
        onCropModeChanged?(true)
    }

    func resetCrop() {
        finishCropping()
        crop = LivePinGeometry.fullCrop
        updateDisplayedImage()
        if let size = displayedPointSize { onCropChanged?(size) }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        bounds.fill()
        guard let image = displayedImage else { return }
        let rect = imageDrawRect(for: image)
        if let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            context.interpolationQuality = .none
            context.translateBy(x: rect.minX, y: rect.maxY)
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(origin: .zero, size: rect.size))
            context.restoreGState()
        }
        if let start = selectionStart, let end = selectionEnd, let imageRect = selectionImageRect,
           let selection = LivePinGeometry.selection(from: start, to: end, in: imageRect) {
            NSColor.controlAccentColor.withAlphaComponent(0.2).setFill()
            selection.fill()
            NSColor.controlAccentColor.setStroke()
            let outline = NSBezierPath(rect: selection)
            outline.lineWidth = 2
            outline.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let image = displayedImage else { return }
        let point = convert(event.locationInWindow, from: nil)
        let rect = imageDrawRect(for: image)
        if isCropping || event.modifierFlags.contains(.option) {
            guard rect.contains(point) else { return }
            if !isCropping { beginCropping() }
            window?.makeKeyAndOrderFront(nil)
            window?.makeFirstResponder(self)
            selectionStart = point
            selectionEnd = point
            selectionImageRect = rect
            needsDisplay = true
        } else if event.modifierFlags.contains(.command) {
            window?.performDrag(with: event)
        } else if let clip = enclosingScrollView?.contentView {
            panStart = event.locationInWindow
            panOrigin = clip.bounds.origin
            NSCursor.closedHand.push()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if let start = panStart, let scroll = enclosingScrollView {
            let point = event.locationInWindow
            let origin = CGPoint(x: panOrigin.x - (point.x - start.x),
                                 y: panOrigin.y + (point.y - start.y))
            let clip = scroll.contentView
            let visible = clip.constrainBoundsRect(CGRect(origin: origin, size: clip.bounds.size))
            clip.scroll(to: visible.origin)
            scroll.reflectScrolledClipView(clip)
            return
        }
        guard selectionStart != nil else { return }
        selectionEnd = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if panStart != nil { finishPanning(); return }
        guard let start = selectionStart, let imageRect = selectionImageRect else { return }
        let end = convert(event.locationInWindow, from: nil)
        if let selection = LivePinGeometry.selection(from: start, to: end, in: imageRect),
           let nextCrop = LivePinGeometry.crop(for: selection, in: imageRect, current: crop) {
            crop = nextCrop
            updateDisplayedImage()
            finishCropping()
            if let size = displayedPointSize { onCropChanged?(size) }
        } else {
            cancelCropping()
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53, isCropping { cancelCropping() }
        else { super.keyDown(with: event) }
    }

    private func cancelCropping() {
        if let previous = cropBeforeSelection { crop = previous }
        finishCropping()
        updateDisplayedImage()
        if let size = displayedPointSize { onCropChanged?(size) }
    }

    private func finishCropping() {
        selectionStart = nil
        selectionEnd = nil
        selectionImageRect = nil
        cropBeforeSelection = nil
        isCropping = false
        onCropModeChanged?(false)
        needsDisplay = true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: isCropping ? .crosshair : .openHand)
    }

    private func finishPanning() {
        guard panStart != nil else { return }
        panStart = nil
        NSCursor.pop()
    }

    private func updateDisplayedImage() {
        guard let sourceImage else { return }
        let rect = LivePinGeometry.pixelRect(for: crop,
                                            imageSize: CGSize(width: sourceImage.width, height: sourceImage.height))
        guard let image = sourceImage.cropping(to: rect) else { return }
        displayedImage = image
        updateNativeSize()
    }

    private func imageDrawRect(for image: CGImage) -> CGRect {
        CGRect(origin: .zero, size: displayedPointSize ?? .zero)
    }
}
