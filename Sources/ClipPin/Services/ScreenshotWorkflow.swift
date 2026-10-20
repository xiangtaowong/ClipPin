import AppKit

final class ScreenshotWorkflow {
    var onFeedback: ((String) -> Void)?
    private let capture: any RegionImageCapturing
    private let settings: ScreenshotEditorSettings
    private let pasteboard: NSPasteboard
    private let presentEditor: (Data, @escaping (Data?) -> Void) -> Void
    private var isBusy = false

    init(capture: any RegionImageCapturing, settings: ScreenshotEditorSettings,
         pasteboard: NSPasteboard = .general,
         presentEditor: @escaping (Data, @escaping (Data?) -> Void) -> Void) {
        self.capture = capture
        self.settings = settings
        self.pasteboard = pasteboard
        self.presentEditor = presentEditor
    }

    func captureSelection() {
        guard !isBusy else { return }
        isBusy = true
        let shouldEdit = settings.isEnabled
        capture.captureSelectionImage { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let data?):
                if shouldEdit {
                    self.presentEditor(data) { [weak self] output in
                        guard let self else { return }
                        if let output { self.copy(output) }
                        self.isBusy = false
                    }
                } else {
                    self.copy(data)
                    self.isBusy = false
                }
            case .success(nil): self.isBusy = false
            case .failure(let error):
                self.isBusy = false
                NSLog("ClipPin screenshot failed: \(error.localizedDescription)")
                self.onFeedback?("Screenshot failed. Please try again.")
            }
        }
    }

    private func copy(_ data: Data) {
        let item = NSPasteboardItem()
        item.setData(data, forType: .png)
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
        onFeedback?("Screenshot copied")
    }
}
