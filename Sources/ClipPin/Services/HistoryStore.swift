import AppKit
import Foundation

final class HistoryStore {
    private let fileManager: FileManager
    private let maxItems: Int
    private let rootDirectoryURL: URL
    private let imagesDirectoryURL: URL
    private let metadataURL: URL

    private(set) var items: [ClipItem] = []
    var onChange: (([ClipItem]) -> Void)?
    var storageRootURL: URL { rootDirectoryURL }

    init(
        maxItems: Int = 100,
        fileManager: FileManager = .default,
        rootDirectoryURL: URL? = nil
    ) throws {
        self.maxItems = maxItems
        self.fileManager = fileManager

        if let rootDirectoryURL {
            self.rootDirectoryURL = rootDirectoryURL
        } else {
            self.rootDirectoryURL = try HistoryStore.defaultRootDirectoryURL(fileManager: fileManager)
        }

        self.imagesDirectoryURL = self.rootDirectoryURL.appendingPathComponent("images", isDirectory: true)
        self.metadataURL = self.rootDirectoryURL.appendingPathComponent("history.json", isDirectory: false)

        try prepareDirectories()
        try load()
    }

    static func defaultRootDirectoryURL(fileManager: FileManager = .default) throws -> URL {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let currentRoot = appSupport.appendingPathComponent("ClipPin", isDirectory: true)
        let legacyRoot = appSupport.appendingPathComponent("ClipPinboard", isDirectory: true)

        let currentExists = fileManager.fileExists(atPath: currentRoot.path)
        let legacyExists = fileManager.fileExists(atPath: legacyRoot.path)

        if currentExists || !legacyExists {
            return currentRoot
        }

        do {
            try fileManager.moveItem(at: legacyRoot, to: currentRoot)
            return currentRoot
        } catch {
            NSLog("ClipPin failed to migrate legacy storage directory: \(error.localizedDescription)")
            return legacyRoot
        }
    }

    func add(_ snapshot: ClipSnapshot) {
        if items.first?.contentHash == snapshot.contentHash {
            return
        }

        let id = UUID()

        let item: ClipItem
        switch snapshot.payload {
        case let .text(text):
            item = ClipItem(
                id: id,
                kind: .text,
                createdAt: snapshot.createdAt,
                sourceAppName: snapshot.sourceAppName,
                contentHash: snapshot.contentHash,
                text: text,
                imageFileName: nil,
                imagePixelWidth: nil,
                imagePixelHeight: nil
            )
        case let .image(data, pixelSize):
            let fileName = "\(id.uuidString).png"
            let imageURL = imageURL(fileName: fileName)

            do {
                try data.write(to: imageURL, options: .atomic)
            } catch {
                NSLog("ClipPin failed to write image data: \(error.localizedDescription)")
                return
            }

            item = ClipItem(
                id: id,
                kind: .image,
                createdAt: snapshot.createdAt,
                sourceAppName: snapshot.sourceAppName,
                contentHash: snapshot.contentHash,
                text: nil,
                imageFileName: fileName,
                imagePixelWidth: pixelSize.width,
                imagePixelHeight: pixelSize.height
            )
        }

        items.insert(item, at: 0)
        trimToMaxItems()
        persist()
        notifyChange()
    }

    func remove(itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        let item = items.remove(at: index)
        deleteBackingFileIfNeeded(for: item)
        persist()
        notifyChange()
    }

    func clear() {
        items.forEach(deleteBackingFileIfNeeded(for:))
        items.removeAll()
        persist()
        notifyChange()
    }

    func image(for item: ClipItem) -> NSImage? {
        guard item.kind == .image,
              let fileName = item.imageFileName
        else {
            return nil
        }

        let url = imageURL(fileName: fileName)
        return NSImage(contentsOf: url)
    }

    func copyToPasteboard(item: ClipItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.kind {
        case .text:
            pasteboard.setString(item.text ?? "", forType: .string)
        case .image:
            guard let image = image(for: item) else { return }
            pasteboard.writeObjects([image])
        }
    }

    private func prepareDirectories() throws {
        try fileManager.createDirectory(
            at: rootDirectoryURL,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: imagesDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    private func load() throws {
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            items = []
            return
        }

        let data = try Data(contentsOf: metadataURL, options: [.mappedIfSafe])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([ClipItem].self, from: data)

        items = decoded.filter { item in
            if item.kind == .text {
                return true
            }
            guard let fileName = item.imageFileName else {
                return false
            }
            return fileManager.fileExists(atPath: imageURL(fileName: fileName).path)
        }

        let didFilterMissingItems = items.count != decoded.count
        let countBeforeTrim = items.count
        trimToMaxItems()
        let didTrim = items.count != countBeforeTrim

        if didFilterMissingItems || didTrim {
            persist()
        }
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            try data.write(to: metadataURL, options: .atomic)
        } catch {
            NSLog("ClipPin failed to persist history: \(error.localizedDescription)")
        }
    }

    private func trimToMaxItems() {
        guard items.count > maxItems else {
            return
        }

        let dropped = items[maxItems...]
        dropped.forEach(deleteBackingFileIfNeeded(for:))
        items = Array(items.prefix(maxItems))
    }

    private func notifyChange() {
        onChange?(items)
    }

    private func imageURL(fileName: String) -> URL {
        imagesDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
    }

    private func deleteBackingFileIfNeeded(for item: ClipItem) {
        guard item.kind == .image,
              let fileName = item.imageFileName
        else {
            return
        }

        let url = imageURL(fileName: fileName)
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: url)
        } catch {
            NSLog("ClipPin failed to delete image file: \(error.localizedDescription)")
        }
    }
}
