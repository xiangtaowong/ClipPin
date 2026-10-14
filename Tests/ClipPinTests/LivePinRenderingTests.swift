import AppKit
import Testing
@testable import ClipPin

@Suite(.serialized)
@MainActor
struct LivePinRenderingTests {
    @Test func liveTextStartsOpaqueWithoutChangingClipboardPinDefaults() throws {
        let _ = NSApplication.shared
        let panel = PinnedLivePanelController(sourceSize: CGSize(width: 320, height: 180))
        defer { panel.close() }
        panel.applyAppearance(settings: PinAppearanceSettings(windowShadowEnabled: false, defaultOpacity: 0.6))
        let window = try #require(panel.window)
        #expect(window.alphaValue == 1)
        #expect(window.hasShadow == false)
        #expect(PinAppearanceSettings.default.defaultOpacity == 0.6)
        let menu = try #require(window.contentView?.menu)
        let opacity = try #require(menu.items.first { $0.title == "Opacity: 100%" }?.submenu)
        let index = try #require(opacity.items.firstIndex { $0.title == "60%" })
        opacity.performActionForItem(at: index)
        #expect(window.alphaValue == 0.6)
    }

    @Test func actualSizeMatchesSourceWindowPointsAcrossDisplayScales() throws {
        let _ = NSApplication.shared
        let size = CGSize(width: 960, height: 540)
        let panel = PinnedLivePanelController(sourceSize: size)
        defer { panel.close() }
        let image = try stripedImage(width: 1920, height: 1080)
        panel.setFrame(LivePinFrame(image: image, pointSize: size))
        let window = try #require(panel.window)
        let scroll = try scrollView(in: window)
        let document = try #require(scroll.documentView)
        #expect(document.bounds.size == size)
        window.setContentSize(CGSize(width: 300, height: 140))
        let menu = try #require(window.contentView?.menu)
        let index = try #require(menu.items.firstIndex { $0.title == "Actual Size (100%)" })
        menu.performActionForItem(at: index)
        let available = try #require((window.screen ?? NSScreen.main)?.visibleFrame.size)
        let border = 2 * scroll.frame.minX
        #expect(window.contentView?.bounds.size == CGSize(width: min(size.width + border, available.width),
                                                         height: min(size.height + border, available.height)))
        #expect(document.bounds.size == size)
        // A different source display/capture density must not change text size.
        panel.setFrame(LivePinFrame(image: try stripedImage(width: 2880, height: 1620), pointSize: size))
        #expect(document.bounds.size == size)
    }

    @Test func resizingViewportNeverSoftensSinglePixelContent() throws {
        let _ = NSApplication.shared
        let pointSize = CGSize(width: 190, height: 110)
        let panel = PinnedLivePanelController(sourceSize: pointSize)
        defer { panel.close() }
        let window = try #require(panel.window)
        let image = try stripedImage(width: 256, height: 128)
        let displayScale = window.backingScaleFactor
        panel.setFrame(LivePinFrame(image: image, pointSize: CGSize(width: 256 / displayScale,
                                                                   height: 128 / displayScale)))
        panel.showStatus(nil)
        let view = try #require(scrollView(in: window).documentView)
        let originalSize = view.bounds.size
        for size in [CGSize(width: 80, height: 64), CGSize(width: 120, height: 90)] {
            window.setContentSize(size)
            #expect(view.bounds.size == originalSize)
            let area = CGRect(origin: .zero, size: CGSize(width: min(size.width, view.bounds.width),
                                                          height: min(size.height, view.bounds.height)))
            let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: area))
            view.cacheDisplay(in: area, to: bitmap)
            try expectNativeContrast(bitmap)
        }
    }

    @Test func scrollingAlignsTheVisibleRegionToPixels() throws {
        let _ = NSApplication.shared
        let panel = PinnedLivePanelController(sourceSize: CGSize(width: 600, height: 260))
        defer { panel.close() }
        let image = try stripedImage(width: 1200, height: 520)
        let window = try #require(panel.window)
        let displayScale = window.backingScaleFactor
        panel.setFrame(LivePinFrame(image: image, pointSize: CGSize(width: 1200 / displayScale,
                                                                   height: 520 / displayScale)))
        window.setContentSize(CGSize(width: 160, height: 100))
        let scroll = try scrollView(in: window)
        scroll.contentView.scroll(to: CGPoint(x: 60.3, y: 20.7))
        let origin = scroll.contentView.bounds.origin
        let scale = window.backingScaleFactor
        #expect(abs(origin.x * scale - (origin.x * scale).rounded()) < 0.0001)
        #expect(abs(origin.y * scale - (origin.y * scale).rounded()) < 0.0001)
        let view = try #require(scroll.documentView)
        let area = scroll.contentView.bounds
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: area))
        view.cacheDisplay(in: area, to: bitmap)
        try expectNativeContrast(bitmap)
    }

    @Test func everyBorderAndCornerCanResizeWithoutScalingTheImage() throws {
        let _ = NSApplication.shared
        let cases: [(CGPoint, CGPoint)] = [
            (CGPoint(x: 3, y: 100), CGPoint(x: 30, y: 0)),
            (CGPoint(x: 329, y: 100), CGPoint(x: 40, y: 0)),
            (CGPoint(x: 100, y: 3), CGPoint(x: 0, y: 30)),
            (CGPoint(x: 100, y: 189), CGPoint(x: 0, y: 40)),
            (CGPoint(x: 3, y: 3), CGPoint(x: 30, y: 20)),
            (CGPoint(x: 329, y: 3), CGPoint(x: 30, y: -20)),
            (CGPoint(x: 3, y: 189), CGPoint(x: -30, y: 20)),
            (CGPoint(x: 329, y: 189), CGPoint(x: 30, y: 20))
        ]
        for (start, delta) in cases {
            let panel = PinnedLivePanelController(sourceSize: CGSize(width: 320, height: 180))
            defer { panel.close() }
            panel.setFrame(LivePinFrame(image: try stripedImage(width: 640, height: 360),
                                       pointSize: CGSize(width: 320, height: 180)))
            panel.showStatus(nil)
            let window = try #require(panel.window)
            window.setContentSize(CGSize(width: 332, height: 192))
            let root = try #require(window.contentView)
            let scroll = try scrollView(in: window)
            let document = try #require(scroll.documentView)
            #expect(root.hitTest(start) === root)
            let original = window.frame
            root.mouseDown(with: try mouseEvent(.leftMouseDown, at: start, in: window))
            let end = CGPoint(x: start.x + delta.x, y: start.y + delta.y)
            root.mouseDragged(with: try mouseEvent(.leftMouseDragged, at: end, in: window))
            root.mouseUp(with: try mouseEvent(.leftMouseUp, at: end, in: window))
            let left = start.x < 6, right = start.x >= 326
            let bottom = start.y < 6, top = start.y >= 186
            #expect(window.frame.width == original.width + (left ? -delta.x : right ? delta.x : 0))
            #expect(window.frame.height == original.height + (bottom ? -delta.y : top ? delta.y : 0))
            if left { #expect(window.frame.maxX == original.maxX) }
            if bottom { #expect(window.frame.maxY == original.maxY) }
            #expect(document.bounds.size == CGSize(width: 320, height: 180))
            #expect(scroll.frame.minX == 6 && scroll.frame.minY == 6)
        }
    }

    @Test func draggingContentPansAndClampsWithoutMovingOrResizingThePin() throws {
        let _ = NSApplication.shared
        let size = CGSize(width: 900, height: 600)
        let panel = PinnedLivePanelController(sourceSize: size)
        defer { panel.close() }
        panel.setFrame(LivePinFrame(image: try stripedImage(width: 1800, height: 1200), pointSize: size))
        panel.showStatus(nil)
        let window = try #require(panel.window)
        window.setContentSize(CGSize(width: 300, height: 200))
        let scroll = try scrollView(in: window)
        let view = try #require(scroll.documentView)
        scroll.contentView.scroll(to: CGPoint(x: 60, y: 20))
        let frame = window.frame
        view.mouseDown(with: try mouseEvent(.leftMouseDown, at: CGPoint(x: 100, y: 80), in: window))
        view.mouseDragged(with: try mouseEvent(.leftMouseDragged, at: CGPoint(x: 50, y: 110), in: window))
        #expect(scroll.contentView.bounds.origin == CGPoint(x: 110, y: 50))
        view.mouseDragged(with: try mouseEvent(.leftMouseDragged, at: CGPoint(x: -2000, y: 2000), in: window))
        let visible = scroll.contentView.bounds
        #expect(visible.minX >= 0 && visible.minY >= 0)
        #expect(visible.maxX <= view.bounds.maxX && visible.maxY <= view.bounds.maxY)
        view.mouseUp(with: try mouseEvent(.leftMouseUp, at: CGPoint(x: -2000, y: 2000), in: window))
        #expect(window.frame == frame)
        #expect(view.bounds.size == size)
    }

    @Test func shrinkingFromTheCornerKeepsTheOppositeCornerAndMinimumSize() throws {
        let _ = NSApplication.shared
        let panel = PinnedLivePanelController(sourceSize: CGSize(width: 320, height: 180))
        defer { panel.close() }
        let window = try #require(panel.window)
        let root = try #require(window.contentView)
        let frame = window.frame
        root.mouseDown(with: try mouseEvent(.leftMouseDown, at: CGPoint(x: 3, y: 3), in: window))
        root.mouseDragged(with: try mouseEvent(.leftMouseDragged, at: CGPoint(x: 2000, y: 2000), in: window))
        root.mouseUp(with: try mouseEvent(.leftMouseUp, at: CGPoint(x: 2000, y: 2000), in: window))
        #expect(window.frame.size == window.contentMinSize)
        #expect(window.frame.maxX == frame.maxX && window.frame.maxY == frame.maxY)
    }

    private func mouseEvent(_ type: NSEvent.EventType, at point: CGPoint, in window: NSWindow) throws -> NSEvent {
        try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    }

    private func scrollView(in window: NSWindow) throws -> NSScrollView {
        try #require(window.contentView?.subviews.compactMap { $0 as? NSScrollView }.first)
    }

    private func expectNativeContrast(_ bitmap: NSBitmapImageRep) throws {
        let y = bitmap.pixelsHigh / 2
        var grayPixels = 0
        var contrastedPairs = 0
        var previous: CGFloat?
        for x in 10..<(bitmap.pixelsWide - 10) {
            let color = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
            let value = color.redComponent
            if value > 0.08 && value < 0.92 { grayPixels += 1 }
            if let previous, abs(value - previous) > 0.8 { contrastedPairs += 1 }
            previous = value
        }
        #expect(grayPixels == 0)
        #expect(contrastedPairs > (bitmap.pixelsWide - 20) * 9 / 10)
    }

    private func stripedImage(width: Int, height: Int) throws -> CGImage {
        let context = try #require(CGContext(data: nil, width: width, height: height,
                                             bitsPerComponent: 8, bytesPerRow: width * 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setShouldAntialias(false)
        for x in 0..<width {
            context.setFillColor(CGColor(gray: x.isMultiple(of: 2) ? 0 : 1, alpha: 1))
            context.fill(CGRect(x: x, y: 0, width: 1, height: height))
        }
        return try #require(context.makeImage())
    }
}
