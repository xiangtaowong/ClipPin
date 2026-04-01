import AppKit
import Foundation

final class ClipboardMonitor {
    private let pasteboard: NSPasteboard
    private var timer: Timer?
    private var lastChangeCount: Int
    private let pollInterval: TimeInterval

    var onSnapshot: ((ClipSnapshot) -> Void)?

    init(
        pasteboard: NSPasteboard = .general,
        pollInterval: TimeInterval = 0.6
    ) {
        self.pasteboard = pasteboard
        self.pollInterval = pollInterval
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(
            timeInterval: pollInterval,
            target: self,
            selector: #selector(pollPasteboard),
            userInfo: nil,
            repeats: true
        )
        timer?.tolerance = pollInterval * 0.3
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    @objc
    private func pollPasteboard() {
        let newCount = pasteboard.changeCount
        guard newCount != lastChangeCount else { return }
        lastChangeCount = newCount

        guard let snapshot = readSnapshot() else { return }
        onSnapshot?(snapshot)
    }

    private func readSnapshot() -> ClipSnapshot? {
        let sourceAppName = sourceApplicationName()

        if let text = pasteboard.string(forType: .string) {
            let rawText = text.trimmingCharacters(in: .newlines)
            guard !rawText.isEmpty else {
                return nil
            }
            let hash = Hashing.sha256Hex(Data(rawText.utf8))
            return ClipSnapshot(
                createdAt: Date(),
                sourceAppName: sourceAppName,
                contentHash: hash,
                payload: .text(rawText)
            )
        }

        guard let image = NSImage(pasteboard: pasteboard),
              let normalized = ImageUtilities.normalizedPNGData(from: image)
        else {
            return nil
        }

        let hash = Hashing.sha256Hex(normalized.data)
        return ClipSnapshot(
            createdAt: Date(),
            sourceAppName: sourceAppName,
            contentHash: hash,
            payload: .image(data: normalized.data, pixelSize: normalized.pixelSize)
        )
    }

    private func sourceApplicationName() -> String? {
        let app = NSWorkspace.shared.frontmostApplication
        let ownBundleID = Bundle.main.bundleIdentifier
        if app?.bundleIdentifier == ownBundleID {
            return nil
        }
        return app?.localizedName
    }
}
