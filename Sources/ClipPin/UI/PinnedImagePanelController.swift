import AppKit

final class PinnedImagePanelController: NSWindowController, NSWindowDelegate, PinAppearanceConfigurable {
    var onClose: (() -> Void)?

    private let image: NSImage
    private let imageView = DraggableImageView()

    init(image: NSImage) {
        self.image = image

        let initialContentSize = PinnedImagePanelController.initialContentSize(for: image.size)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialContentSize),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentMinSize = NSSize(width: 80, height: 80)
        if image.size.width > 0, image.size.height > 0 {
            panel.contentAspectRatio = image.size
        }

        super.init(window: panel)
        panel.delegate = self
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    private func deletePinnedItem(_ sender: Any?) {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    func applyAppearance(settings: PinAppearanceSettings) {
        window?.hasShadow = settings.windowShadowEnabled
        window?.alphaValue = settings.defaultOpacity
    }

    private func setupUI() {
        guard let root = window?.contentView else {
            return
        }

        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.clear.cgColor

        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.menu = makeContextMenu()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: root.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        let deleteItem = NSMenuItem(
            title: "Delete Pin",
            action: #selector(deletePinnedItem(_:)),
            keyEquivalent: ""
        )
        deleteItem.target = self
        menu.addItem(deleteItem)
        return menu
    }

    private static func initialContentSize(for imageSize: NSSize) -> NSSize {
        let maxWidth: CGFloat = 520
        let maxHeight: CGFloat = 420
        guard imageSize.width > 0, imageSize.height > 0 else {
            return NSSize(width: 320, height: 240)
        }

        let widthScale = maxWidth / imageSize.width
        let heightScale = maxHeight / imageSize.height
        let scale = min(1, widthScale, heightScale)
        let width = max(120, imageSize.width * scale)
        let height = max(80, imageSize.height * scale)
        return NSSize(width: width, height: height)
    }
}

private final class DraggableImageView: NSImageView {
    override var mouseDownCanMoveWindow: Bool {
        true
    }
}
