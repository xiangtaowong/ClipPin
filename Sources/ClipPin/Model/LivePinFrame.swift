import CoreGraphics

struct LivePinFrame {
    let image: CGImage
    /// Source window content size in points, independent of capture/display DPI.
    let pointSize: CGSize
    /// Native source pixels before ScreenCaptureKit fits a resized window.
    let nativePixelSize: CGSize
    let contentScale: CGFloat

    init(image: CGImage, pointSize: CGSize, nativePixelSize: CGSize? = nil, contentScale: CGFloat = 1) {
        self.image = image
        self.pointSize = pointSize
        self.nativePixelSize = nativePixelSize ?? CGSize(width: image.width, height: image.height)
        self.contentScale = contentScale
    }

    var isNativeResolution: Bool {
        contentScale >= 0.9999 && contentScale <= 1.0001
            && CGFloat(image.width) == nativePixelSize.width
            && CGFloat(image.height) == nativePixelSize.height
    }
}
