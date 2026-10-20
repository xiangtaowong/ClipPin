import Foundation

final class ScreenshotEditorSettings {
    private let defaults: UserDefaults
    private let key = "screenshot.showEditorAfterCapture"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var isEnabled: Bool {
        get { defaults.object(forKey: key) as? Bool ?? true }
        set { defaults.set(newValue, forKey: key) }
    }
}
