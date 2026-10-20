import AppKit

enum ScreenshotTool: String, CaseIterable {
    case draw = "Draw", highlight = "Highlight", arrow = "Arrow"
    case rectangle = "Rectangle", ellipse = "Ellipse", text = "Text"
}

struct ScreenshotAnnotation {
    var tool: ScreenshotTool
    var points: [CGPoint]
    var color: NSColor
    var width: CGFloat
    var text = ""

    func draw() {
        guard let start = points.first, let end = points.last else { return }
        let ink = color.withAlphaComponent(tool == .highlight ? 0.3 : 1)
        ink.setStroke()
        ink.setFill()
        let path = NSBezierPath()
        path.lineWidth = tool == .highlight ? width * 5 : width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        let rect = NSRect(x: min(start.x, end.x), y: min(start.y, end.y),
                          width: abs(end.x - start.x), height: abs(end.y - start.y))
        switch tool {
        case .text:
            (text as NSString).draw(at: start, withAttributes: [
                .font: NSFont.systemFont(ofSize: max(16, width * 6), weight: .semibold),
                .foregroundColor: ink
            ])
            return
        case .rectangle: path.appendRect(rect)
        case .ellipse: path.appendOval(in: rect)
        case .draw, .highlight:
            if points.count == 1 {
                let diameter = path.lineWidth
                NSBezierPath(ovalIn: NSRect(x: start.x - diameter / 2, y: start.y - diameter / 2,
                                           width: diameter, height: diameter)).fill()
                return
            }
            path.move(to: start)
            for point in points.dropFirst() { path.line(to: point) }
        case .arrow:
            path.move(to: start)
            path.line(to: end)
            let angle = atan2(end.y - start.y, end.x - start.x)
            let length = min(max(12, width * 4), hypot(end.x - start.x, end.y - start.y) * 0.5)
            for offset in [-CGFloat.pi / 6, CGFloat.pi / 6] {
                path.move(to: end)
                path.line(to: CGPoint(x: end.x - length * cos(angle + offset),
                                     y: end.y - length * sin(angle + offset)))
            }
        }
        path.stroke()
    }
}

final class ScreenshotDocument {
    let image: CGImage
    let originalData: Data
    private(set) var annotations: [ScreenshotAnnotation] = []
    // Crop and annotations share one undo timeline. Keep source pixels intact so
    // undoing a crop restores both the image and any marks outside the crop.
    private struct State {
        var annotations: [ScreenshotAnnotation]
        var cropRect: CGRect
    }
    private(set) var cropRect: CGRect
    private var undoHistory: [State] = []
    private var redoHistory: [State] = []
    var canUndo: Bool { !undoHistory.isEmpty }
    var canRedo: Bool { !redoHistory.isEmpty }
    var size: CGSize { cropRect.size }
    private var sourceRect: CGRect { CGRect(x: 0, y: 0, width: image.width, height: image.height) }
    private var state: State {
        get { State(annotations: annotations, cropRect: cropRect) }
        set { annotations = newValue.annotations; cropRect = newValue.cropRect }
    }

    init?(data: Data) {
        guard let bitmap = NSBitmapImageRep(data: data), let image = bitmap.cgImage else { return nil }
        self.image = image
        self.originalData = data
        self.cropRect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
    }

    func add(_ annotation: ScreenshotAnnotation) {
        undoHistory.append(state)
        redoHistory.removeAll()
        annotations.append(annotation)
    }

    func clear() {
        guard !annotations.isEmpty else { return }
        undoHistory.append(state)
        redoHistory.removeAll()
        annotations.removeAll()
    }

    func undo() {
        guard let previous = undoHistory.popLast() else { return }
        redoHistory.append(state)
        state = previous
    }

    func redo() {
        guard let next = redoHistory.popLast() else { return }
        undoHistory.append(state)
        state = next
    }

    @discardableResult
    func crop(to selection: CGRect) -> Bool {
        guard let rect = ScreenshotCropSelection.pixelRect(selection, in: size) else { return false }
        let next = rect.offsetBy(dx: cropRect.minX, dy: cropRect.minY)
        guard next != cropRect else { return false }
        undoHistory.append(state)
        redoHistory.removeAll()
        cropRect = next
        return true
    }

    func draw(in context: CGContext, draft: ScreenshotAnnotation? = nil) {
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: CGRect(origin: .zero, size: size))
        context.translateBy(x: -cropRect.minX, y: -cropRect.minY)
        context.draw(image, in: sourceRect)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        defer { NSGraphicsContext.restoreGraphicsState() }
        for annotation in annotations { annotation.draw() }
        draft?.draw()
    }

    func pngData() -> Data? {
        // Preserve the source bytes and pixel dimensions when nothing was changed.
        guard !annotations.isEmpty || cropRect != sourceRect else { return originalData }
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        draw(in: context)
        guard let output = context.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: output).representation(using: .png, properties: [:])
    }
}
