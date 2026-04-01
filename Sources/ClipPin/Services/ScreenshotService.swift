import Foundation

final class ScreenshotService {
    func captureSelectionToClipboard() {
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
}
