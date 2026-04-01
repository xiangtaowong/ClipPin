import Foundation

final class ScreenshotHotKeyStore {
    private enum Keys {
        static let keyCode = "screenshotHotKey.keyCode"
        static let modifiers = "screenshotHotKey.modifiers"
    }

    private let userDefaults: UserDefaults
    private(set) var shortcut: HotKeyShortcut

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        let keyCode = userDefaults.object(forKey: Keys.keyCode) as? Int
        let modifiers = userDefaults.object(forKey: Keys.modifiers) as? Int

        if let keyCode, let modifiers {
            self.shortcut = HotKeyShortcut(
                keyCode: UInt32(keyCode),
                modifiers: UInt32(modifiers)
            )
        } else {
            self.shortcut = .screenshotDefault
        }
    }

    func setShortcut(_ shortcut: HotKeyShortcut) {
        self.shortcut = shortcut
        userDefaults.set(Int(shortcut.keyCode), forKey: Keys.keyCode)
        userDefaults.set(Int(shortcut.modifiers), forKey: Keys.modifiers)
    }
}
