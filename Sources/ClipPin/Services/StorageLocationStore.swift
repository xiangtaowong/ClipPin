import Foundation

final class StorageLocationStore {
    private enum Keys {
        static let customRootPath = "storage.customRootPath"
    }

    private let userDefaults: UserDefaults
    private let fileManager: FileManager

    init(
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.userDefaults = userDefaults
        self.fileManager = fileManager
    }

    func defaultRootDirectoryURL() throws -> URL {
        try HistoryStore.defaultRootDirectoryURL(fileManager: fileManager)
    }

    func currentRootDirectoryURL() throws -> URL {
        if let customRootDirectoryURL {
            return customRootDirectoryURL
        }
        return try defaultRootDirectoryURL()
    }

    var customRootDirectoryURL: URL? {
        guard let path = userDefaults.string(forKey: Keys.customRootPath),
              !path.isEmpty
        else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    }

    func setCustomRootDirectoryURL(_ url: URL) {
        userDefaults.set(url.standardizedFileURL.path, forKey: Keys.customRootPath)
    }

    func resetToDefault() {
        userDefaults.removeObject(forKey: Keys.customRootPath)
    }
}
