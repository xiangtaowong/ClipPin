import Foundation

enum ClipItemKind: String, Codable {
    case text
    case image
}

struct ClipItem: Codable, Identifiable {
    let id: UUID
    let kind: ClipItemKind
    let createdAt: Date
    let sourceAppName: String?
    let contentHash: String

    let text: String?
    let imageFileName: String?
    let imagePixelWidth: Double?
    let imagePixelHeight: Double?

    var previewText: String {
        switch kind {
        case .text:
            guard let text else { return "" }
            let lines = text
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            if lines.isEmpty {
                return "(empty text)"
            }

            return lines.prefix(3).joined(separator: "\n")
        case .image:
            let width = Int(imagePixelWidth ?? 0)
            let height = Int(imagePixelHeight ?? 0)
            if width > 0 && height > 0 {
                return "Image \(width)×\(height)"
            }
            return "Image"
        }
    }
}

enum ClipSnapshotPayload {
    case text(String)
    case image(data: Data, pixelSize: CGSize)
}

struct ClipSnapshot {
    let createdAt: Date
    let sourceAppName: String?
    let contentHash: String
    let payload: ClipSnapshotPayload
}
