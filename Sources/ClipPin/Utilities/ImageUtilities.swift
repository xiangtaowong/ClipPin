import AppKit
import Foundation

enum ImageUtilities {
    static let maxImageDimension: CGFloat = 2400

    static func normalizedPNGData(
        from image: NSImage,
        maxDimension: CGFloat = maxImageDimension
    ) -> (data: Data, pixelSize: CGSize)? {
        guard let cgImage = image.asCGImage() else {
            return nil
        }

        let sourceWidth = CGFloat(cgImage.width)
        let sourceHeight = CGFloat(cgImage.height)
        guard sourceWidth > 0, sourceHeight > 0 else {
            return nil
        }

        let maxSource = max(sourceWidth, sourceHeight)
        let scale = maxSource > maxDimension ? (maxDimension / maxSource) : 1
        let targetWidth = max(1, Int(round(sourceWidth * scale)))
        let targetHeight = max(1, Int(round(sourceHeight * scale)))

        let outputImage: CGImage
        if scale < 1 {
            guard let context = CGContext(
                data: nil,
                width: targetWidth,
                height: targetHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return nil
            }

            context.interpolationQuality = .high
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

            guard let scaled = context.makeImage() else {
                return nil
            }
            outputImage = scaled
        } else {
            outputImage = cgImage
        }

        let bitmap = NSBitmapImageRep(cgImage: outputImage)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        return (
            data: data,
            pixelSize: CGSize(width: outputImage.width, height: outputImage.height)
        )
    }

    static func thumbnail(for image: NSImage, maxDimension: CGFloat) -> NSImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }

        let maxSource = max(size.width, size.height)
        guard maxSource > maxDimension else { return image }

        let scale = maxDimension / maxSource
        let targetSize = NSSize(width: size.width * scale, height: size.height * scale)
        let target = NSImage(size: targetSize)
        target.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1
        )
        target.unlockFocus()
        return target
    }

    static func menuThumbnail(
        for image: NSImage,
        canvasPointSize: CGFloat,
        backingScale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2.0
    ) -> NSImage? {
        guard let cgImage = image.asCGImage() else {
            return nil
        }

        let canvasPixels = max(1, Int(round(canvasPointSize * backingScale)))
        let canvasRect = CGRect(x: 0, y: 0, width: canvasPixels, height: canvasPixels)

        guard let context = CGContext(
            data: nil,
            width: canvasPixels,
            height: canvasPixels,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.clear(canvasRect)
        context.interpolationQuality = .high
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)

        let sourceWidth = CGFloat(cgImage.width)
        let sourceHeight = CGFloat(cgImage.height)
        guard sourceWidth > 0, sourceHeight > 0 else {
            return nil
        }

        let fitScale = min(CGFloat(canvasPixels) / sourceWidth, CGFloat(canvasPixels) / sourceHeight)
        let drawWidth = sourceWidth * fitScale
        let drawHeight = sourceHeight * fitScale
        let drawRect = CGRect(
            x: (CGFloat(canvasPixels) - drawWidth) * 0.5,
            y: (CGFloat(canvasPixels) - drawHeight) * 0.5,
            width: drawWidth,
            height: drawHeight
        )

        context.draw(cgImage, in: drawRect)

        guard let output = context.makeImage() else {
            return nil
        }

        let thumbnail = NSImage(cgImage: output, size: NSSize(width: canvasPointSize, height: canvasPointSize))
        thumbnail.size = NSSize(width: canvasPointSize, height: canvasPointSize)
        return thumbnail
    }
}

private extension NSImage {
    func asCGImage() -> CGImage? {
        var proposedRect = NSRect(origin: .zero, size: size)
        if let cgImage = cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) {
            return cgImage
        }

        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else {
            return nil
        }

        return bitmap.cgImage
    }
}
