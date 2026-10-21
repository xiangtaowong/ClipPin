import AppKit

final class HistoryShortcutMenu: NSMenu {
    var onCaptureShortcut: ((NSEvent) -> Bool)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if onCaptureShortcut?(event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }
}

struct HistoryImagePreviewLayout {
    let frame: CGRect
    let imageRect: CGRect

    static func make(pixelSize: CGSize, menuFrame: CGRect, screen: CGRect,
                     backingScale: CGFloat) -> Self? {
        guard pixelSize.width > 0, pixelSize.height > 0, backingScale > 0 else { return nil }
        let gap: CGFloat = 10
        let rightRoom = max(0, screen.maxX - menuFrame.maxX - gap)
        let leftRoom = max(0, menuFrame.minX - screen.minX - gap)
        let idealWidth = min(700, max(180, pixelSize.width / backingScale + 24))
        let useRight = rightRoom >= idealWidth || rightRoom >= leftRoom
        let availableWidth = min(700, useRight ? rightRoom : leftRoom)
        let availableHeight = min(560, screen.height)
        guard availableWidth > 40, availableHeight > 60 else { return nil }
        let nativeSize = CGSize(width: pixelSize.width / backingScale, height: pixelSize.height / backingScale)
        // Never blow a thumbnail up. Read the full stored image and keep at most
        // one source pixel per display pixel, fitting large images to the screen.
        let fit = min(1, (availableWidth - 24) / nativeSize.width,
                      (availableHeight - 46) / nativeSize.height)
        let width = max(1 / backingScale, floor(nativeSize.width * fit * backingScale) / backingScale)
        let height = max(1 / backingScale, floor(nativeSize.height * fit * backingScale) / backingScale)
        let panelWidth = min(availableWidth, max(180, width + 24))
        let panelHeight = height + 46
        let x = useRight ? menuFrame.maxX + gap : menuFrame.minX - gap - panelWidth
        let y = min(max(menuFrame.maxY - panelHeight, screen.minY), screen.maxY - panelHeight)
        return Self(frame: CGRect(x: x, y: y, width: panelWidth, height: panelHeight),
                    imageRect: CGRect(x: (panelWidth - width) / 2, y: 34, width: width, height: height))
    }
}

final class HistoryImagePreviewController: NSWindowController {
    private let preview = HistoryImagePreviewView()
    private(set) var visibleItemID: UUID?

    init() {
        let panel = HistoryImagePreviewPanel(contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        super.init(window: panel)
        panel.contentView = preview
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(image: NSImage, itemID: UUID, menuFrame: CGRect, screen: NSScreen) {
        guard visibleItemID != itemID else { return }
        guard let pixels = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let layout = HistoryImagePreviewLayout.make(
                pixelSize: CGSize(width: pixels.width, height: pixels.height),
                menuFrame: menuFrame, screen: screen.visibleFrame, backingScale: screen.backingScaleFactor)
        else { hide(); return }
        visibleItemID = itemID
        preview.image = pixels
        preview.imageRect = layout.imageRect
        preview.caption = "\(pixels.width) × \(pixels.height) px"
        window?.setFrame(layout.frame, display: false)
        preview.needsDisplay = true
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
        visibleItemID = nil
        preview.image = nil
    }
}

private final class HistoryImagePreviewPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class HistoryImagePreviewView: NSView {
    var image: CGImage?
    var imageRect = CGRect.zero
    var caption = ""

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
        if let image, let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            context.interpolationQuality = .high
            context.draw(image, in: imageRect)
            context.restoreGState()
        }
        (caption as NSString).draw(at: CGPoint(x: 12, y: 10), withAttributes: [
            .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor
        ])
    }
}
