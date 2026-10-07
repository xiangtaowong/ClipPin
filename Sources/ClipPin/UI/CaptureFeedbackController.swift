import AppKit

final class CaptureFeedbackController {
    private var panel: NSPanel?
    private var dismissTask: DispatchWorkItem?

    func show(_ message: String) {
        dismissTask?.cancel()
        panel?.orderOut(nil)

        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.sizeToFit()
        let size = NSSize(width: label.frame.width + 40, height: 48)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true
        label.frame.origin = NSPoint(x: 20, y: (size.height - label.frame.height) / 2)
        background.addSubview(label)
        panel.contentView = background

        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 60))
        }
        self.panel = panel
        panel.orderFrontRegardless()

        let dismissTask = DispatchWorkItem { [weak self] in
            self?.panel?.orderOut(nil)
            self?.panel = nil
        }
        self.dismissTask = dismissTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: dismissTask)
    }
}
