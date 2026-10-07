import Foundation
import Vision

struct RecognizedTextLine {
    let text: String
    let bounds: CGRect
}

enum TextRecognitionService {
    static func recognizeText(in imageData: Data) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        let supportedLanguages = try request.supportedRecognitionLanguages()
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"].filter {
            supportedLanguages.contains($0)
        }

        try VNImageRequestHandler(data: imageData, options: [:]).perform([request])
        let lines = (request.results ?? []).compactMap { observation -> RecognizedTextLine? in
            guard let text = observation.topCandidates(1).first?.string else {
                return nil
            }
            return RecognizedTextLine(text: text, bounds: observation.boundingBox)
        }
        return normalizedText(from: lines)
    }

    static func normalizedText(from lines: [RecognizedTextLine]) -> String {
        // Vision uses bottom-left coordinates; group rows before sorting left to right.
        let sorted = lines.sorted { $0.bounds.midY > $1.bounds.midY }
        var rows: [[RecognizedTextLine]] = []
        for line in sorted {
            if let anchor = rows.last?.first,
               abs(anchor.bounds.midY - line.bounds.midY) <= min(anchor.bounds.height, line.bounds.height) * 0.5 {
                rows[rows.count - 1].append(line)
            } else {
                rows.append([line])
            }
        }
        let orderedText = rows.flatMap { row in
            row.sorted { $0.bounds.minX < $1.bounds.minX }.map(\.text)
        }
        return removingLineBreaks(from: orderedText)
    }

    static func removingLineBreaks(from lines: [String]) -> String {
        let cleaned = lines.flatMap { $0.components(separatedBy: .newlines) }
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .filter { !$0.isEmpty }

        return cleaned.reduce(into: "") { result, line in
            if let last = result.last, let first = line.first,
               !isCJK(last), !isCJK(first),
               !"([{\u{201c}\u{2018}\u{ff08}".contains(last),
               !".,;:!?%)]}\u{ff0c}\u{3002}\u{3001}\u{ff1a}\u{ff1b}\u{ff01}\u{ff1f}\u{ff09}\u{3011}\u{300b}\u{201d}\u{2019}".contains(first),
               last != "-" {
                result += " "
            }
            result += line
        }
    }

    private static func isCJK(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF,
                 0x20000...0x323AF, 0x3000...0x303F, 0xFF01...0xFF60:
                return true
            default:
                return false
            }
        }
    }
}
