import Foundation

final class TextCaptureHotKeyStore {
    private enum Keys {
        static let keyCode = "textCaptureHotKey.keyCode"
        static let modifiers = "textCaptureHotKey.modifiers"
    }

    private let userDefaults: UserDefaults
    private(set) var shortcut: HotKeyShortcut

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let keyCode = userDefaults.object(forKey: Keys.keyCode) as? Int,
           let modifiers = userDefaults.object(forKey: Keys.modifiers) as? Int,
           let savedKeyCode = UInt32(exactly: keyCode),
           let savedModifiers = UInt32(exactly: modifiers) {
            shortcut = HotKeyShortcut(keyCode: savedKeyCode, modifiers: savedModifiers)
        } else {
            shortcut = .textCaptureDefault
        }
    }

    func setShortcut(_ shortcut: HotKeyShortcut) {
        self.shortcut = shortcut
        userDefaults.set(Int(shortcut.keyCode), forKey: Keys.keyCode)
        userDefaults.set(Int(shortcut.modifiers), forKey: Keys.modifiers)
    }
}
