import CoreGraphics
import Testing
@testable import ClipPin

struct LivePinGeometryTests {
    @Test func keepsRetinaPixelsAboveTheOld2560Limit() {
        #expect(LivePinGeometry.capturePixelSize(for: CGSize(width: 3008, height: 1692), pixelScale: 2)
                == CGSize(width: 6016, height: 3384))
        #expect(LivePinGeometry.capturePixelSize(for: CGSize(width: 3840, height: 2160), pixelScale: 2)
                == CGSize(width: 7680, height: 4320))
    }

    @Test func sourceResizeCanRequestLargerNativeCapture() {
        let before = LivePinGeometry.capturePixelSize(for: CGSize(width: 800, height: 600), pixelScale: 2)
        let after = LivePinGeometry.capturePixelSize(for: CGSize(width: 1600, height: 900), pixelScale: 2)
        #expect(before == CGSize(width: 1600, height: 1200))
        #expect(after == CGSize(width: 3200, height: 1800))
    }

    @Test func integralCropKeepsItsExtraEdgePixelAtNativeSize() {
        #expect(LivePinGeometry.croppedPointSize(pixelSize: CGSize(width: 41, height: 51),
                sourcePixelSize: CGSize(width: 1000, height: 1000), sourcePointSize: CGSize(width: 500, height: 500))
                == CGSize(width: 20.5, height: 25.5))
    }

    @Test func recoversSourcePointsWhenHardwareDownscalesAFrame() {
        #expect(LivePinGeometry.sourcePointSize(pixelSize: CGSize(width: 6000, height: 3000),
                                               pixelScale: 2, contentScale: 0.75)
                == CGSize(width: 4000, height: 2000))
        #expect(LivePinGeometry.sourcePointSize(pixelSize: CGSize(width: 6000, height: 3000),
                                               pixelScale: 0, contentScale: 1) == nil)
    }

    @Test func captureGeometryRejectsInvalidValuesWithoutShrinkingLargeWindows() {
        #expect(LivePinGeometry.capturePixelSize(for: .zero, pixelScale: 2) == CGSize(width: 2, height: 2))
        #expect(LivePinGeometry.capturePixelSize(for: CGSize(width: CGFloat.infinity, height: 100), pixelScale: 2)
                == CGSize(width: 2, height: 2))
        #expect(LivePinGeometry.capturePixelSize(for: CGSize(width: 20000, height: 10000), pixelScale: 2)
                == CGSize(width: 40000, height: 20000))
    }

    @Test func cropExcludesLetterboxingAndUsesTopLeftCoordinates() throws {
        let fitted = LivePinGeometry.fittedRect(imageSize: CGSize(width: 1000, height: 500),
                                                in: CGRect(x: 0, y: 0, width: 600, height: 600))
        #expect(fitted == CGRect(x: 0, y: 150, width: 600, height: 300))
        let crop = try #require(LivePinGeometry.crop(
            for: CGRect(x: 60, y: 360, width: 480, height: 60), in: fitted,
            current: LivePinGeometry.fullCrop))
        #expect(abs(crop.minX - 0.1) < 0.00001)
        #expect(abs(crop.minY - 0.7) < 0.00001)
        #expect(abs(crop.width - 0.8) < 0.00001)
        #expect(abs(crop.height - 0.2) < 0.00001)
    }

    @Test func reverseDragIsClampedToImage() {
        let selection = LivePinGeometry.selection(
            from: CGPoint(x: 200, y: 200), to: CGPoint(x: -20, y: -20),
            in: CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(selection == CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(LivePinGeometry.selection(from: .zero, to: CGPoint(x: 2, y: 3),
                                         in: CGRect(x: 0, y: 0, width: 100, height: 100)) == nil)
    }

    @Test func successiveCropMapsBackToFullSource() throws {
        let crop = try #require(LivePinGeometry.crop(
            for: CGRect(x: 50, y: 25, width: 100, height: 50),
            in: CGRect(x: 0, y: 0, width: 200, height: 100),
            current: CGRect(x: 0.2, y: 0.6, width: 0.6, height: 0.2)))
        #expect(abs(crop.minX - 0.35) < 0.00001)
        #expect(abs(crop.minY - 0.65) < 0.00001)
        #expect(abs(crop.width - 0.3) < 0.00001)
        #expect(abs(crop.height - 0.1) < 0.00001)
    }

    @Test func cropScalesToRetinaPixelsAndStaysInsideImage() {
        let rect = LivePinGeometry.pixelRect(for: CGRect(x: 0.1, y: 0.8, width: 0.8, height: 0.2),
                                            imageSize: CGSize(width: 2000, height: 1000))
        #expect(rect == CGRect(x: 200, y: 800, width: 1600, height: 200))
        let clipped = LivePinGeometry.pixelRect(for: CGRect(x: 0.9, y: 0.9, width: 0.2, height: 0.2),
                                               imageSize: CGSize(width: 100, height: 100))
        #expect(clipped == CGRect(x: 90, y: 90, width: 10, height: 10))
    }

    @Test func blankGeometryCannotCreateCrop() {
        #expect(LivePinGeometry.fittedRect(imageSize: .zero, in: .zero) == .zero)
        #expect(LivePinGeometry.crop(for: .zero, in: .zero, current: LivePinGeometry.fullCrop) == nil)
        #expect(LivePinGeometry.crop(for: CGRect(x: 200, y: 200, width: 10, height: 10),
                                    in: CGRect(x: 0, y: 0, width: 100, height: 100),
                                    current: LivePinGeometry.fullCrop) == nil)
    }
}
