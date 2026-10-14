import AppKit
import ScreenCaptureKit

@available(macOS 14.0, *)
@MainActor
final class LivePinManager: NSObject, SCContentSharingPickerObserver {
    private let appearanceProvider: () -> PinAppearanceSettings
    private let picker = SCContentSharingPicker.shared
    private var sessions: [UUID: LivePinSession] = [:]
    private var isPicking = false
    private var isObservingPicker = false
    var onError: ((String) -> Void)?

    init(appearanceProvider: @escaping () -> PinAppearanceSettings) {
        self.appearanceProvider = appearanceProvider
        super.init()
    }

    func chooseWindow() {
        // Refresh idle picker registration immediately before use. A missed
        // callback must not leave subsequent requests stuck behind isPicking.
        if sessions.isEmpty {
            picker.isActive = false
            if isObservingPicker { picker.remove(self) }
            isObservingPicker = false
        }
        var configuration = SCContentSharingPickerConfiguration()
        configuration.allowedPickerModes = [.singleWindow]
        configuration.excludedBundleIDs = [Bundle.main.bundleIdentifier ?? "com.clippin.app"]
        // A pin keeps its source. Create another pin to capture a different window.
        configuration.allowsChangingSelectedContent = false
        picker.defaultConfiguration = configuration
        // Make room for the requested pin without interrupting existing streams.
        picker.maximumStreamCount = sessions.count + 1
        if !isObservingPicker {
            picker.add(self)
            isObservingPicker = true
        }
        isPicking = true
        picker.isActive = true
        picker.present(using: .window)
    }

    func closeAll() {
        isPicking = false
        let activeSessions = Array(sessions.values)
        for session in activeSessions { session.close() }
        sessions.removeAll()
        picker.isActive = false
        if isObservingPicker { picker.remove(self) }
        isObservingPicker = false
    }

    private func selected(_ filter: SCContentFilter, stream: SCStream?) {
        isPicking = false
        NSLog("ClipPin Live Pin selection received (existing stream: %@)", stream == nil ? "no" : "yes")
        // Source changes are disabled in the picker configuration.
        guard stream == nil else { return }
        guard filter.style == .window, filter.contentRect.width > 0,
              filter.contentRect.height > 0 else {
            onError?("Choose a single application window for Live Pin.")
            updatePickerActivity()
            return
        }
        let id = UUID()
        let session = LivePinSession(filter: filter, appearance: appearanceProvider())
        sessions[id] = session
        session.onClose = { [weak self] in
            self?.sessions.removeValue(forKey: id)
            self?.updatePickerActivity()
        }
        session.start()
    }

    private func updatePickerActivity() {
        picker.isActive = isPicking || !sessions.isEmpty
    }

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker,
                                         didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { @MainActor [weak self] in self?.selected(filter, stream: stream) }
    }

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor [weak self] in
            self?.isPicking = false
            self?.updatePickerActivity()
        }
    }

    nonisolated func contentSharingPickerStartDidFailWithError(_ error: Error) {
        Task { @MainActor [weak self] in
            self?.isPicking = false
            self?.updatePickerActivity()
            self?.onError?(error.localizedDescription)
        }
    }
}
