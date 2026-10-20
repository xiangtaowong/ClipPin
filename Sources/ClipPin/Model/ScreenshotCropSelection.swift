import Foundation

/// Geometry in the current crop's pixel coordinates, with a bottom-left origin.
struct ScreenshotCropSelection {
    private(set) var rect: CGRect?
    private var gesture: Gesture?

    private enum Gesture {
        case create(CGPoint)
        case move(CGPoint, CGRect)
        case resize(CGPoint, CGRect, Int)
    }

    static func pixelRect(_ selection: CGRect, in size: CGSize) -> CGRect? {
        let values = [selection.origin.x, selection.origin.y, selection.width, selection.height,
                      size.width, size.height]
        guard values.allSatisfy(\.isFinite), size.width >= 1, size.height >= 1 else { return nil }
        let clipped = selection.standardized.intersection(CGRect(origin: .zero, size: size))
        guard !clipped.isNull, clipped.width >= 1, clipped.height >= 1 else { return nil }
        // Include touched edge pixels and never scale or discard fractional edges.
        // View-to-image conversion can put an integer edge a few ULPs away
        // from its pixel; avoid adding a spurious row/column in that case.
        func snapped(_ value: CGFloat) -> CGFloat {
            abs(value - value.rounded()) < 1e-7 ? value.rounded() : value
        }
        let left = floor(snapped(clipped.minX)), bottom = floor(snapped(clipped.minY))
        let right = ceil(snapped(clipped.maxX)), top = ceil(snapped(clipped.maxY))
        return CGRect(x: left, y: bottom, width: right - left, height: top - bottom)
    }

    var handles: [CGPoint] {
        guard let rect else { return [] }
        return [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.midX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.midY),
                CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.midX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.midY)]
    }

    mutating func begin(at point: CGPoint, in size: CGSize, tolerance: CGFloat) {
        let point = clamped(point, to: size)
        if let rect,
           let index = handles.indices.min(by: { distance(point, handles[$0]) < distance(point, handles[$1]) }),
           distance(point, handles[index]) <= tolerance {
            gesture = .resize(point, rect, index)
        } else if let rect, rect.contains(point) {
            gesture = .move(point, rect)
        } else {
            rect = CGRect(origin: point, size: .zero)
            gesture = .create(point)
        }
    }

    mutating func drag(to point: CGPoint, in size: CGSize) {
        let point = clamped(point, to: size)
        switch gesture {
        case .create(let start):
            rect = CGRect(x: min(start.x, point.x), y: min(start.y, point.y),
                          width: abs(start.x - point.x), height: abs(start.y - point.y))
        case .move(let start, let original):
            rect = CGRect(x: min(max(0, original.minX + point.x - start.x), size.width - original.width),
                          y: min(max(0, original.minY + point.y - start.y), size.height - original.height),
                          width: original.width, height: original.height)
        case .resize(let start, let original, let handle):
            var left = original.minX, right = original.maxX
            var bottom = original.minY, top = original.maxY
            if [0, 6, 7].contains(handle) { left += point.x - start.x }
            if [2, 3, 4].contains(handle) { right += point.x - start.x }
            if [0, 1, 2].contains(handle) { bottom += point.y - start.y }
            if [4, 5, 6].contains(handle) { top += point.y - start.y }
            left = min(max(0, left), size.width)
            right = min(max(0, right), size.width)
            bottom = min(max(0, bottom), size.height)
            top = min(max(0, top), size.height)
            rect = CGRect(x: min(left, right), y: min(bottom, top),
                          width: abs(right - left), height: abs(top - bottom))
        case nil: break
        }
    }

    mutating func end() { gesture = nil }

    private func clamped(_ point: CGPoint, to size: CGSize) -> CGPoint {
        CGPoint(x: min(max(0, point.x), size.width), y: min(max(0, point.y), size.height))
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
}
