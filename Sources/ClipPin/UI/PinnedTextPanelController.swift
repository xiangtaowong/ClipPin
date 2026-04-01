import AppKit

final class PinnedTextPanelController: NSWindowController, NSWindowDelegate, PinAppearanceConfigurable {
    var onClose: (() -> Void)?

    private let contentController: PinnedTextContentViewController

    init(text: String) {
        self.contentController = PinnedTextContentViewController(text: text)

        let initialSize = PinnedTextPanelController.initialContentSize(for: text)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
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
        panel.contentMinSize = NSSize(width: 120, height: 60)

        super.init(window: panel)
        panel.delegate = self
        panel.contentViewController = contentController
        contentController.onDeleteRequest = { [weak panel] in
            panel?.close()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    func applyAppearance(settings: PinAppearanceSettings) {
        window?.hasShadow = settings.windowShadowEnabled
        window?.alphaValue = settings.defaultOpacity
    }

    private static func initialContentSize(for text: String) -> NSSize {
        let font = NSFont.systemFont(ofSize: 26, weight: .regular)
        let maxWidth: CGFloat = 520
        let minWidth: CGFloat = 140
        let minHeight: CGFloat = 70
        let padding: CGFloat = 20

        let measured = (text as NSString).boundingRect(
            with: NSSize(width: maxWidth - (padding * 2), height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )

        let width = min(maxWidth, max(minWidth, ceil(measured.width) + (padding * 2)))
        let height = max(minHeight, ceil(measured.height) + (padding * 2))
        return NSSize(width: width, height: height)
    }
}

private final class PinnedTextContentViewController: NSViewController {
    var onDeleteRequest: (() -> Void)?

    private let text: String
    private let textView = DraggableTextView()

    init(text: String) {
        self.text = text
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        setupUI()
    }

    @objc
    private func deletePinnedItem(_ sender: Any?) {
        onDeleteRequest?()
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor

        textView.isEditable = false
        textView.isSelectable = false
        textView.isRichText = false
        textView.string = text
        textView.font = NSFont.systemFont(ofSize: 26, weight: .regular)
        textView.textColor = .labelColor
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineBreakMode = .byWordWrapping
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.minSize = .zero
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.menu = makeContextMenu()

        view.menu = textView.menu
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10)
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
}

private final class DraggableTextView: NSTextView {
    override var mouseDownCanMoveWindow: Bool {
        true
    }
}
