import Foundation
import CoreGraphics

protocol RegionImageCapturing {
    func captureSelectionImage(completion: @escaping (Result<Data?, Error>) -> Void)
}

final class ScreenshotService: RegionImageCapturing {
    var onPermissionDenied: (() -> Void)?
    private var isCapturing = false

    func captureSelectionToClipboard() {
        captureSelection(toClipboard: true) { result in
            if case .failure(let error) = result {
                NSLog("ClipPin screenshot failed: \(error.localizedDescription)")
            }
        }
    }

    func captureSelectionImage(completion: @escaping (Result<Data?, Error>) -> Void) {
        captureSelection(toClipboard: false, completion: completion)
    }

    private func captureSelection(
        toClipboard: Bool,
        completion: @escaping (Result<Data?, Error>) -> Void
    ) {
        guard !isCapturing else {
            completion(.success(nil))
            return
        }
        guard ensureScreenCapturePermission() else {
            onPermissionDenied?()
            completion(.success(nil))
            return
        }
        isCapturing = true

        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result<Data?, Error> {
                let directory = FileManager.default.temporaryDirectory
                    .appendingPathComponent("ClipPin-TextCapture-\(UUID().uuidString)", isDirectory: true)
                let imageURL = directory.appendingPathComponent("selection.png")
                if !toClipboard {
                    try FileManager.default.createDirectory(
                        at: directory,
                        withIntermediateDirectories: false,
                        attributes: [.posixPermissions: 0o700]
                    )
                }
                defer {
                    if !toClipboard {
                        try? FileManager.default.removeItem(at: directory)
                    }
                }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                process.arguments = toClipboard
                    ? ["-i", "-c"]
                    : ["-i", "-s", "-x", "-t", "png", imageURL.path]

                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    NSLog("ClipPin screenshot command exited with status: \(process.terminationStatus)")
                }

                // Escape cancels selection without creating an image or changing the clipboard.
                guard !toClipboard, FileManager.default.fileExists(atPath: imageURL.path) else {
                    return nil
                }
                return try Data(contentsOf: imageURL)
            }
            DispatchQueue.main.async {
                self.isCapturing = false
                completion(result)
            }
        }
    }

    private func ensureScreenCapturePermission() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        return CGRequestScreenCaptureAccess()
    }
}
