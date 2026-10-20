import AppKit
import Testing
@testable import ClipPin

@Suite(.serialized)
@MainActor
struct ScreenshotEditorTests {
    @Test func exportPreservesResolutionOrientationAndUndoHistory() throws {
        let document = try ScreenshotDocument(data: sourcePNG()).unwrap()
        let original = try document.pngData().unwrap()
        #expect(original == document.originalData)
        document.add(ScreenshotAnnotation(tool: .draw,
            points: [CGPoint(x: 20, y: 20), CGPoint(x: 80, y: 20)], color: .red, width: 6))
        let bitmap = try NSBitmapImageRep(data: document.pngData().unwrap()).unwrap()
        #expect(bitmap.pixelsWide == 200 && bitmap.pixelsHigh == 100)
        let ink = try bitmap.colorAt(x: 50, y: 79)?.usingColorSpace(.deviceRGB).unwrap()
        #expect(ink?.redComponent ?? 0 > 0.9)
        #expect(ink?.greenComponent ?? 1 < 0.25)
        // A black source marker in the upper left must stay there after export.
        #expect(try bitmap.colorAt(x: 5, y: 5).unwrap().brightnessComponent < 0.1)
        #expect(try bitmap.colorAt(x: 5, y: 94).unwrap().brightnessComponent > 0.9)
        document.clear()
        #expect(document.annotations.isEmpty)
        document.undo()
        #expect(document.annotations.count == 1)
        document.undo()
        #expect(document.pngData() == original)
        document.redo()
        #expect(document.annotations.count == 1)
        document.undo()
        document.add(ScreenshotAnnotation(tool: .ellipse, points: [.zero, CGPoint(x: 40, y: 40)],
                                           color: .blue, width: 3))
        #expect(!document.canRedo)
    }

    @Test func everyToolRendersAndHighlighterIsTranslucent() throws {
        for tool in ScreenshotTool.allCases {
            let document = try ScreenshotDocument(data: sourcePNG()).unwrap()
            document.add(ScreenshotAnnotation(tool: tool,
                points: [CGPoint(x: 40, y: 30), CGPoint(x: 140, y: 60)], color: .red,
                width: 3, text: "Hello"))
            let data = try document.pngData().unwrap()
            #expect(data != document.originalData)
            let bitmap = try NSBitmapImageRep(data: data).unwrap()
            // Verify an actual red mark exists, rather than just re-encoded PNG bytes.
            var marked = 0
            for x in 20..<180 {
                for y in 10..<90 {
                    let color = try bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB).unwrap()
                    if let color, color.redComponent - color.greenComponent > 0.15 { marked += 1 }
                }
            }
            #expect(marked > 10, "Missing pixels for \(tool.rawValue)")
            if tool == .highlight {
                let color = try bitmap.colorAt(x: 90, y: 54)?.usingColorSpace(.deviceRGB).unwrap()
                #expect((color?.greenComponent ?? 0) > 0.5)
                #expect((color?.greenComponent ?? 1) < 0.85)
            }
        }
    }

    @Test func scaledCanvasPlacesStrokesInOriginalPixelCoordinates() throws {
        let _ = NSApplication.shared
        let document = try ScreenshotDocument(data: sourcePNG()).unwrap()
        let canvas = ScreenshotCanvas(document: document)
        canvas.scale = 2
        canvas.setFrameSize(CGSize(width: 400, height: 200))
        let window = NSWindow(contentRect: canvas.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = canvas
        for (type, point) in [(NSEvent.EventType.leftMouseDown, CGPoint(x: 40, y: 40)),
                              (.leftMouseDragged, CGPoint(x: 160, y: 40)),
                              (.leftMouseUp, CGPoint(x: 160, y: 40))] {
            let event = try NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1).unwrap()
            switch type {
            case .leftMouseDown: canvas.mouseDown(with: event)
            case .leftMouseDragged: canvas.mouseDragged(with: event)
            default: canvas.mouseUp(with: event)
            }
        }
        let annotation = try document.annotations.first.unwrap()
        #expect(annotation.points.first == CGPoint(x: 20, y: 20))
        #expect(annotation.points.last == CGPoint(x: 80, y: 20))
    }

    @Test func workflowHonorsToggleCancelAndReentrancy() throws {
        let defaults = try UserDefaults(suiteName: "ClipPinTests.\(UUID())").unwrap()
        defer { defaults.removeObject(forKey: "screenshot.showEditorAfterCapture") }
        let settings = ScreenshotEditorSettings(defaults: defaults)
        #expect(settings.isEnabled)
        let capture = EditorCaptureStub()
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("keep me", forType: .string)
        var editorCompletion: ((Data?) -> Void)?
        var presentations = 0
        let workflow = ScreenshotWorkflow(capture: capture, settings: settings, pasteboard: pasteboard) { _, done in
            presentations += 1
            editorCompletion = done
        }
        let data = try sourcePNG()
        workflow.captureSelection()
        workflow.captureSelection()
        #expect(capture.calls == 1)
        capture.complete?(.success(data))
        #expect(presentations == 1)
        #expect(pasteboard.string(forType: .string) == "keep me")
        workflow.captureSelection()
        #expect(capture.calls == 1)
        editorCompletion?(nil)
        #expect(pasteboard.string(forType: .string) == "keep me")
        workflow.captureSelection()
        capture.complete?(.success(data))
        editorCompletion?(data)
        #expect(pasteboard.data(forType: .png) == data)
        settings.isEnabled = false
        #expect(!ScreenshotEditorSettings(defaults: defaults).isEnabled)
        workflow.captureSelection()
        capture.complete?(.success(data))
        #expect(presentations == 2)
        #expect(pasteboard.data(forType: .png) == data)
        pasteboard.clearContents()
        pasteboard.setString("cancel selection", forType: .string)
        workflow.captureSelection()
        capture.complete?(.success(nil))
        #expect(pasteboard.string(forType: .string) == "cancel selection")
        workflow.captureSelection()
        capture.complete?(.failure(NSError(domain: "test", code: 1)))
        workflow.captureSelection()
        #expect(capture.calls == 6)
    }

    @Test func closingEditorCancelsExactlyOnce() throws {
        let _ = NSApplication.shared
        var completions = 0
        let editor = try ScreenshotEditorController(data: sourcePNG()) { data in
            #expect(data == nil)
            completions += 1
        }.unwrap()
        editor.close()
        #expect(completions == 1)
        editor.close()
        #expect(completions == 1)
    }

    @Test func cropKeepsSourcePixelsAnnotationsAndOneUndoTimeline() throws {
        let document = try ScreenshotDocument(data: sourcePNG()).unwrap()
        let original = document.originalData
        document.add(ScreenshotAnnotation(tool: .draw,
            points: [CGPoint(x: 40, y: 40), CGPoint(x: 100, y: 40)], color: .red, width: 4))
        #expect(document.crop(to: CGRect(x: 20, y: 10, width: 100, height: 70)))
        let cropped = try NSBitmapImageRep(data: document.pngData().unwrap()).unwrap()
        #expect(cropped.pixelsWide == 100 && cropped.pixelsHigh == 70)
        let red = try cropped.colorAt(x: 40, y: 39)?.usingColorSpace(.deviceRGB).unwrap()
        #expect((red?.redComponent ?? 0) - (red?.greenComponent ?? 1) > 0.7)
        #expect(document.crop(to: CGRect(x: 5.4, y: 5.2, width: 50.1, height: 30.2)))
        #expect(document.cropRect == CGRect(x: 25, y: 15, width: 51, height: 31))
        document.undo()
        #expect(document.size == CGSize(width: 100, height: 70))
        document.undo()
        #expect(document.size == CGSize(width: 200, height: 100))
        #expect(document.annotations.count == 1)
        document.undo()
        #expect(document.pngData() == original)
        document.redo()
        document.redo()
        #expect(document.size == CGSize(width: 100, height: 70))
        #expect(document.annotations.count == 1)
        document.clear()
        #expect(document.size == CGSize(width: 100, height: 70))
        document.undo()
        #expect(document.annotations.count == 1)
    }

    @Test func cropPreservesTopLeftOrientationAndRejectsInvalidSelections() throws {
        let document = try ScreenshotDocument(data: sourcePNG()).unwrap()
        #expect(!document.crop(to: CGRect(x: 20, y: 20, width: 0, height: 10)))
        #expect(!document.crop(to: CGRect(x: 300, y: 0, width: 10, height: 10)))
        #expect(!document.crop(to: CGRect(origin: .zero, size: document.size)))
        #expect(!document.canUndo)
        #expect(document.crop(to: CGRect(x: 0, y: 80, width: 20, height: 20)))
        let bitmap = try NSBitmapImageRep(data: document.pngData().unwrap()).unwrap()
        #expect(bitmap.pixelsWide == 20 && bitmap.pixelsHigh == 20)
        #expect(try bitmap.colorAt(x: 5, y: 5).unwrap().brightnessComponent < 0.1)
        #expect(try bitmap.colorAt(x: 5, y: 15).unwrap().brightnessComponent > 0.9)
        document.undo()
        #expect(document.crop(to: CGRect(x: -5, y: -5, width: 15, height: 15)))
        #expect(document.size == CGSize(width: 10, height: 10))
        #expect(ScreenshotCropSelection.pixelRect(CGRect(x: CGFloat.nan, y: 0, width: 10, height: 10),
                                                 in: document.size) == nil)
        #expect(ScreenshotCropSelection.pixelRect(CGRect(x: 20 - 1e-12, y: 10, width: 40, height: 30),
                                                 in: CGSize(width: 200, height: 100))
                == CGRect(x: 20, y: 10, width: 40, height: 30))
    }

    @Test func cropSelectionMovesResizesEveryHandleAndClampsToImage() throws {
        let size = CGSize(width: 200, height: 100)
        func selection() -> ScreenshotCropSelection {
            var result = ScreenshotCropSelection()
            result.begin(at: CGPoint(x: 100, y: 60), in: size, tolerance: 3)
            result.drag(to: CGPoint(x: 20, y: 20), in: size)
            result.end()
            return result
        }
        let expected = [CGRect(x: 25, y: 27, width: 75, height: 33),
                        CGRect(x: 20, y: 27, width: 80, height: 33),
                        CGRect(x: 20, y: 27, width: 85, height: 33),
                        CGRect(x: 20, y: 20, width: 85, height: 40),
                        CGRect(x: 20, y: 20, width: 85, height: 47),
                        CGRect(x: 20, y: 20, width: 80, height: 47),
                        CGRect(x: 25, y: 20, width: 75, height: 47),
                        CGRect(x: 25, y: 20, width: 75, height: 40)]
        for index in 0..<8 {
            var crop = selection()
            let start = crop.handles[index]
            crop.begin(at: start, in: size, tolerance: 3)
            crop.drag(to: CGPoint(x: start.x + 5, y: start.y + 7), in: size)
            crop.end()
            #expect(crop.rect == expected[index])
        }
        var crop = selection()
        crop.begin(at: CGPoint(x: 50, y: 40), in: size, tolerance: 3)
        crop.drag(to: CGPoint(x: -100, y: 200), in: size)
        #expect(crop.rect == CGRect(x: 0, y: 60, width: 80, height: 40))
        crop = selection()
        crop.begin(at: CGPoint(x: 20, y: 20), in: size, tolerance: 3)
        crop.drag(to: CGPoint(x: 120, y: 80), in: size)
        #expect(crop.rect == CGRect(x: 100, y: 60, width: 20, height: 20))
    }

    @Test func cropButtonsConfirmCancelUndoAndCopyTheCorrectRegion() throws {
        let _ = NSApplication.shared
        var output: Data?
        let editor = try ScreenshotEditorController(data: sourcePNG()) { output = $0 }.unwrap()
        defer { editor.close() }
        let window = try editor.window.unwrap()
        let root = try window.contentView.unwrap()
        root.layoutSubtreeIfNeeded()
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        let views = descendants(root)
        let canvas = try views.compactMap { $0 as? ScreenshotCanvas }.first.unwrap()
        func button(_ title: String) throws -> NSButton {
            try views.compactMap { $0 as? NSButton }.first { $0.title == title }.unwrap()
        }
        func drag(from start: CGPoint, to end: CGPoint) throws {
            for (type, point) in [(NSEvent.EventType.leftMouseDown, start), (.leftMouseDragged, end), (.leftMouseUp, end)] {
                let event = try NSEvent.mouseEvent(with: type,
                    location: canvas.convert(CGPoint(x: point.x * canvas.scale, y: point.y * canvas.scale), to: nil),
                    modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil,
                    eventNumber: 0, clickCount: 1, pressure: 1).unwrap()
                switch type {
                case .leftMouseDown: canvas.mouseDown(with: event)
                case .leftMouseDragged: canvas.mouseDragged(with: event)
                default: canvas.mouseUp(with: event)
                }
            }
        }
        try button("Crop").performClick(nil)
        #expect(canvas.isCropping)
        #expect(try !button("Copy & Close").isEnabled)
        #expect(try !button("Apply Crop").isEnabled)
        try button("−").performClick(nil)
        #expect(canvas.scale < 1)
        try drag(from: CGPoint(x: 20, y: 10), to: CGPoint(x: 120, y: 80))
        try button("Cancel Crop").performClick(nil)
        #expect(canvas.document.size == CGSize(width: 200, height: 100))
        #expect(!canvas.document.canUndo)
        let tools = try views.compactMap { $0 as? NSSegmentedControl }.first.unwrap()
        tools.selectedSegment = 2
        NSApp.sendAction(tools.action!, to: tools.target, from: tools)
        #expect(canvas.tool == .arrow)
        tools.selectedSegment = 0
        NSApp.sendAction(tools.action!, to: tools.target, from: tools)
        try button("Crop").performClick(nil)
        try drag(from: CGPoint(x: 20, y: 10), to: CGPoint(x: 120, y: 80))
        try button("Apply Crop").performClick(nil)
        #expect(!canvas.isCropping)
        #expect(canvas.document.size == CGSize(width: 100, height: 70))
        try button("Undo").performClick(nil)
        #expect(canvas.document.size == CGSize(width: 200, height: 100))
        try button("Redo").performClick(nil)
        #expect(canvas.document.size == CGSize(width: 100, height: 70))
        // A new mark uses local crop coordinates while remaining anchored in the source.
        try drag(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 60, y: 20))
        #expect(canvas.document.annotations.last?.points.first == CGPoint(x: 30, y: 30))
        try button("Copy & Close").performClick(nil)
        let bitmap = try NSBitmapImageRep(data: output.unwrap()).unwrap()
        #expect(bitmap.pixelsWide == 100 && bitmap.pixelsHigh == 70)
        let red = try bitmap.colorAt(x: 30, y: 49)?.usingColorSpace(.deviceRGB).unwrap()
        #expect((red?.redComponent ?? 0) - (red?.greenComponent ?? 1) > 0.6)
    }

    private func sourcePNG() throws -> Data {
        let context = try CGContext(data: nil, width: 200, height: 100, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue).unwrap()
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 90, width: 10, height: 10))
        return try NSBitmapImageRep(cgImage: context.makeImage().unwrap())
            .representation(using: .png, properties: [:]).unwrap()
    }
}

private final class EditorCaptureStub: RegionImageCapturing {
    var calls = 0
    var complete: ((Result<Data?, Error>) -> Void)?
    func captureSelectionImage(completion: @escaping (Result<Data?, Error>) -> Void) {
        calls += 1
        complete = completion
    }
}

private extension Optional {
    func unwrap() throws -> Wrapped { try #require(self) }
}
