import AppKit

final class TextCaptureService {
    var onFeedback: ((String) -> Void)?

    private let screenshotService: any RegionImageCapturing
    private let pasteboard: NSPasteboard
    private var isProcessing = false

    init(screenshotService: any RegionImageCapturing, pasteboard: NSPasteboard = .general) {
        self.screenshotService = screenshotService
        self.pasteboard = pasteboard
    }

    func captureSelectionToText() {
        guard !isProcessing else { return }
        isProcessing = true

        screenshotService.captureSelectionImage { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(nil):
                self.isProcessing = false
            case .failure(let error):
                self.isProcessing = false
                self.reportFailure(error)
            case .success(let data?):
                self.onFeedback?("Recognizing text...")
                DispatchQueue.global(qos: .userInitiated).async {
                    let recognition = Result { try TextRecognitionService.recognizeText(in: data) }
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        switch recognition {
                        case .success(let text) where text.isEmpty:
                            self.onFeedback?("No text found. Clipboard unchanged.")
                        case .success(let text):
                            self.pasteboard.clearContents()
                            self.pasteboard.setString(text, forType: .string)
                            self.onFeedback?("Text copied (line breaks removed)")
                        case .failure(let error):
                            self.reportFailure(error)
                        }
                    }
                }
            }
        }
    }

    private func reportFailure(_ error: Error) {
        NSLog("ClipPin text capture failed: \(error.localizedDescription)")
        onFeedback?("Text capture failed. Please try again.")
    }
}
