import CoreGraphics

/// Crop coordinates are normalized to the full window, with a top-left origin.
/// Keeping them independent of screen coordinates lets the source window move.
enum LivePinGeometry {
    static let fullCrop = CGRect(x: 0, y: 0, width: 1, height: 1)

    static func capturePixelSize(for pointSize: CGSize, pixelScale: CGFloat) -> CGSize {
        guard pointSize.width.isFinite, pointSize.height.isFinite,
              pointSize.width > 0, pointSize.height > 0, pixelScale.isFinite else {
            return CGSize(width: 2, height: 2)
        }
        let scale = max(1, pixelScale)
        let width = pointSize.width * scale
        let height = pointSize.height * scale
        guard width.isFinite, height.isFinite else { return CGSize(width: 2, height: 2) }
        // Do not silently lower quality for a large window. Capture failures
        // are reported by ScreenCaptureKit instead of shrinking the source.
        return CGSize(width: max(2, width.rounded(.up)),
                      height: max(2, height.rounded(.up)))
    }

    static func sourcePointSize(pixelSize: CGSize, pixelScale: CGFloat, contentScale: CGFloat) -> CGSize? {
        guard pixelScale.isFinite, contentScale.isFinite,
              pixelScale > 0, contentScale > 0,
              pixelSize.width.isFinite, pixelSize.height.isFinite,
              pixelSize.width > 0, pixelSize.height > 0 else { return nil }
        let scale = pixelScale * contentScale
        return CGSize(width: pixelSize.width / scale, height: pixelSize.height / scale)
    }

    static func croppedPointSize(pixelSize: CGSize, sourcePixelSize: CGSize, sourcePointSize: CGSize) -> CGSize {
        guard sourcePixelSize.width > 0, sourcePixelSize.height > 0 else { return .zero }
        return CGSize(width: pixelSize.width / sourcePixelSize.width * sourcePointSize.width,
                      height: pixelSize.height / sourcePixelSize.height * sourcePointSize.height)
    }

    static func fittedRect(imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              bounds.width > 0, bounds.height > 0 else { return .zero }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    static func selection(from start: CGPoint, to end: CGPoint, in imageRect: CGRect) -> CGRect? {
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                          width: abs(end.x - start.x), height: abs(end.y - start.y))
            .intersection(imageRect)
        guard !rect.isNull, rect.width >= 8, rect.height >= 8 else { return nil }
        return rect
    }

    static func crop(for selection: CGRect, in imageRect: CGRect, current: CGRect) -> CGRect? {
        guard imageRect.width > 0, imageRect.height > 0 else { return nil }
        let selection = selection.intersection(imageRect)
        guard !selection.isNull, selection.width > 0, selection.height > 0 else { return nil }
        let crop = CGRect(
            x: current.minX + (selection.minX - imageRect.minX) / imageRect.width * current.width,
            y: current.minY + (selection.minY - imageRect.minY) / imageRect.height * current.height,
            width: selection.width / imageRect.width * current.width,
            height: selection.height / imageRect.height * current.height
        ).intersection(fullCrop)
        return crop.isNull || crop.isEmpty ? nil : crop
    }

    static func pixelRect(for crop: CGRect, imageSize: CGSize) -> CGRect {
        let bounds = CGRect(origin: .zero, size: imageSize)
        return CGRect(x: crop.minX * imageSize.width, y: crop.minY * imageSize.height,
                      width: crop.width * imageSize.width, height: crop.height * imageSize.height)
            .integral.intersection(bounds)
    }
}
