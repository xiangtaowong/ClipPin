import Foundation
import CoreGraphics

final class ScreenshotService {
    var onPermissionDenied: (() -> Void)?

    func captureSelectionToClipboard() {
        guard ensureScreenCapturePermission() else {
            DispatchQueue.main.async { [weak self] in
                self?.onPermissionDenied?()
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", "-c"]

            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    NSLog("ClipPin screenshot command exited with status: \(process.terminationStatus)")
                }
            } catch {
                NSLog("ClipPin failed to run screenshot command: \(error.localizedDescription)")
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
