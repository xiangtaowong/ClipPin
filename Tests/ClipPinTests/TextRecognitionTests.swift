import AppKit
import Carbon.HIToolbox
import Testing
@testable import ClipPin

@Suite(.serialized)
@MainActor
struct TextRecognitionTests {
    @Test
    func testRemovesChineseLineBreaksWithoutAddingSpaces() {
        #expect(
            TextRecognitionService.removingLineBreaks(from: ["  框选后识别\r\n文字", "并复制到剪贴板。  "]) ==
            "框选后识别文字并复制到剪贴板。"
        )
    }

    @Test
    func testEnglishWordsRemainSeparateAndWhitespaceIsCollapsed() {
        #expect(
            TextRecognitionService.removingLineBreaks(from: ["  Copy\tthis", "text\nlocally.  ", "", "\r\n"]) ==
            "Copy this text locally."
        )
    }

    @Test
    func testMixedTextAndPunctuation() {
        #expect(
            TextRecognitionService.removingLineBreaks(from: ["使用", "ClipPin", "识别文字", "，然后复制。"]) ==
            "使用ClipPin识别文字，然后复制。"
        )
        #expect(
            TextRecognitionService.removingLineBreaks(from: ["Hello", ", world", "!", "Next sentence."]) ==
            "Hello, world! Next sentence."
        )
    }

    @Test
    func testPreservesHyphenatedWordsAcrossLines() {
        #expect(
            TextRecognitionService.removingLineBreaks(from: ["An always-", "on-top card"]) ==
            "An always-on-top card"
        )
    }

    @Test
    func testOrdersRowsTopToBottomAndFragmentsLeftToRight() {
        let lines = [
            RecognizedTextLine(text: "third row", bounds: CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.08)),
            RecognizedTextLine(text: "right", bounds: CGRect(x: 0.6, y: 0.81, width: 0.2, height: 0.08)),
            RecognizedTextLine(text: "second row", bounds: CGRect(x: 0.1, y: 0.5, width: 0.5, height: 0.08)),
            RecognizedTextLine(text: "left", bounds: CGRect(x: 0.1, y: 0.8, width: 0.2, height: 0.08))
        ]
        #expect(TextRecognitionService.normalizedText(from: lines) == "left right second row third row")
    }

    @Test
    func testEmptyRecognitionProducesNoText() {
        #expect(TextRecognitionService.normalizedText(from: []) == "")
        #expect(TextRecognitionService.removingLineBreaks(from: [" \n\t", ""]) == "")
    }

    @Test
    func testActualOCRRecognizesRenderedEnglishLines() throws {
        let data = try renderedImage(lines: ["ClipPin OCR", "Copies text locally"])
        #expect(try TextRecognitionService.recognizeText(in: data) == "ClipPin OCR Copies text locally")
    }

    @Test
    func testActualOCRRecognizesRenderedChineseLines() throws {
        let data = try renderedImage(lines: ["框选文字", "自动复制"])
        #expect(try TextRecognitionService.recognizeText(in: data) == "框选文字自动复制")
    }

    @Test
    func testBlankImageReturnsEmptyText() throws {
        #expect(try TextRecognitionService.recognizeText(in: renderedImage(lines: [])) == "")
    }

    @Test
    func testInvalidImageThrows() {
        #expect(throws: (any Error).self) {
            try TextRecognitionService.recognizeText(in: Data("not an image".utf8))
        }
    }

    @Test
    func testTextCaptureShortcutPersistsIndependently() throws {
        let suiteName = "ClipPinTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let screenshot = ScreenshotHotKeyStore(userDefaults: defaults)
        let quickPaste = QuickPasteHotKeyStore(userDefaults: defaults)
        let capture = TextCaptureHotKeyStore(userDefaults: defaults)
        #expect(capture.shortcut == .textCaptureDefault)
        let shortcut = HotKeyShortcut(keyCode: UInt32(kVK_ANSI_3), modifiers: UInt32(cmdKey))
        capture.setShortcut(shortcut)
        #expect(TextCaptureHotKeyStore(userDefaults: defaults).shortcut == shortcut)
        #expect(screenshot.shortcut == .screenshotDefault)
        #expect(quickPaste.shortcut == .quickPasteDefault)
    }

    @Test
    func testCancelledCapturePreservesClipboard() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("Keep this text", forType: .string)
        let capture = StubRegionCapture(result: .success(nil))
        let service = TextCaptureService(screenshotService: capture, pasteboard: pasteboard)
        let previousChangeCount = pasteboard.changeCount
        service.captureSelectionToText()
        #expect(pasteboard.string(forType: .string) == "Keep this text")
        #expect(pasteboard.changeCount == previousChangeCount)
    }

    @Test
    func testFailedCapturePreservesClipboard() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("Keep this text", forType: .string)
        let capture = StubRegionCapture(result: .failure(NSError(domain: "OCRTests", code: 1)))
        let service = TextCaptureService(screenshotService: capture, pasteboard: pasteboard)
        let previousChangeCount = pasteboard.changeCount
        service.captureSelectionToText()
        #expect(pasteboard.string(forType: .string) == "Keep this text")
        #expect(pasteboard.changeCount == previousChangeCount)
    }

    @Test
    func testCaptureCopiesOnlyRecognizedText() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let capture = StubRegionCapture(result: .success(try renderedImage(lines: ["ClipPin OCR", "Copies text locally"])))
        let service = TextCaptureService(screenshotService: capture, pasteboard: pasteboard)
        await withCheckedContinuation { continuation in
            service.onFeedback = { message in
                if message != "Recognizing text..." {
                    continuation.resume()
                }
            }
            service.captureSelectionToText()
        }
        #expect(pasteboard.string(forType: .string) == "ClipPin OCR Copies text locally")
        #expect(pasteboard.data(forType: .png) == nil)
        #expect(pasteboard.data(forType: .tiff) == nil)
    }

    @Test
    func testCaptureWithoutTextPreservesClipboard() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("Keep this text", forType: .string)
        let capture = StubRegionCapture(result: .success(try renderedImage(lines: [])))
        let service = TextCaptureService(screenshotService: capture, pasteboard: pasteboard)
        let previousChangeCount = pasteboard.changeCount
        await withCheckedContinuation { continuation in
            service.onFeedback = { message in
                if message != "Recognizing text..." {
                    continuation.resume()
                }
            }
            service.captureSelectionToText()
        }
        #expect(pasteboard.string(forType: .string) == "Keep this text")
        #expect(pasteboard.changeCount == previousChangeCount)
    }

    private func renderedImage(lines: [String]) throws -> Data {
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 1200, pixelsHigh: 400,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 1200, height: 400).fill()
        for (index, line) in lines.enumerated() {
            (line as NSString).draw(
                at: NSPoint(x: 60, y: 280 - index * 100),
                withAttributes: [.font: NSFont.systemFont(ofSize: 48), .foregroundColor: NSColor.black]
            )
        }
        context.flushGraphics()
        return try #require(bitmap.representation(using: .png, properties: [:]))
    }
}

private final class StubRegionCapture: RegionImageCapturing {
    let result: Result<Data?, Error>

    init(result: Result<Data?, Error>) {
        self.result = result
    }

    func captureSelectionImage(completion: @escaping (Result<Data?, Error>) -> Void) {
        completion(result)
    }
}
