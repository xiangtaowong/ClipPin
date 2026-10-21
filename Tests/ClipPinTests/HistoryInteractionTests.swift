import AppKit
import Carbon.HIToolbox
import Testing
@testable import ClipPin

@Suite(.serialized)
@MainActor
struct HistoryInteractionTests {
    @Test func captureShortcutClosesHistoryBeforeCaptureAndDoesNotSelectAnItem() async throws {
        let _ = NSApplication.shared
        let controller = HistoryMenuController()
        controller.screenshotHotKeyProvider = { HotKeyShortcut(keyCode: 18, modifiers: UInt32(cmdKey)) }
        controller.textCaptureHotKeyProvider = { HotKeyShortcut(keyCode: 20, modifiers: UInt32(cmdKey)) }
        var captures = 0, recognitions = 0, copied = 0
        controller.onScreenshotRequest = { captures += 1 }
        controller.onTextCaptureRequest = { recognitions += 1 }
        controller.onCopyRequest = { _ in copied += 1 }
        controller.menuWillOpen(controller.menu)
        let key = try keyEvent(code: 18, flags: [.command, .capsLock])
        #expect(controller.menu.performKeyEquivalent(with: key))
        #expect(controller.handleCaptureShortcut(key))
        #expect(captures == 0)
        controller.menuDidClose(controller.menu)
        await drainMainQueue()
        #expect(captures == 1)
        #expect(copied == 0)
        controller.menuWillOpen(controller.menu)
        #expect(!controller.handleCaptureShortcut(try keyEvent(code: 18, flags: [])))
        #expect(!controller.handleCaptureShortcut(try keyEvent(code: 18, flags: [.command, .shift])))
        #expect(controller.handleCaptureShortcut(try keyEvent(code: 20, flags: [.command])))
        controller.menuDidClose(controller.menu)
        await drainMainQueue()
        #expect(recognitions == 1)
        #expect(!controller.handleCaptureShortcut(key))
        // Outside menu tracking the action runs immediately.
        controller.performAfterClosing { captures += 1 }
        #expect(captures == 2)
    }

    @Test func menuTrackingReadsConfiguredKeysAndRestoresGlobalRegistration() async throws {
        let _ = NSApplication.shared
        let manager = GlobalHotKeyManager(signature: 0x48544B54, identifier: 47)
        let shortcut = HotKeyShortcut(keyCode: UInt32(kVK_F12), modifiers: UInt32(cmdKey | controlKey | optionKey))
        #expect(manager.register(shortcut: shortcut))
        let controller = HistoryMenuController()
        controller.screenshotHotKeyProvider = { shortcut }
        controller.onMenuTrackingChanged = { manager.setSuspendedForMenu($0) }
        var captures = 0
        controller.onScreenshotRequest = { captures += 1 }
        controller.menuWillOpen(controller.menu)
        #expect(manager.isSuspendedForMenu)
        #expect(controller.handleCaptureShortcut(try keyEvent(code: UInt16(kVK_F12), flags: [.command, .control, .option])))
        #expect(captures == 0)
        controller.menuDidClose(controller.menu)
        #expect(!manager.isSuspendedForMenu)
        await drainMainQueue()
        #expect(captures == 1)
        // Closing and reopening the menu must not lose the configured shortcut.
        controller.menuWillOpen(controller.menu)
        #expect(controller.handleCaptureShortcut(try keyEvent(code: UInt16(kVK_F12), flags: [.command, .control, .option])))
        controller.menuDidClose(controller.menu)
        await drainMainQueue()
        #expect(captures == 2)
    }

    @Test func previewUsesNativePixelsAndStaysBesideTheMenuOnEitherScreenEdge() throws {
        let screen = CGRect(x: -1440, y: 0, width: 1440, height: 900)
        for menu in [CGRect(x: -1400, y: 180, width: 360, height: 600),
                     CGRect(x: -380, y: 180, width: 360, height: 600)] {
            let layout = try #require(HistoryImagePreviewLayout.make(pixelSize: CGSize(width: 1800, height: 1000),
                menuFrame: menu, screen: screen, backingScale: 2))
            #expect(screen.contains(layout.frame))
            #expect(!layout.frame.intersects(menu))
            #expect(layout.imageRect.width > 300)
            #expect(layout.imageRect.width * 2 <= 1800)
            #expect(layout.imageRect.height * 2 <= 1000)
            #expect(abs(layout.imageRect.width / layout.imageRect.height - 1.8) < 0.01)
        }
        let small = try #require(HistoryImagePreviewLayout.make(pixelSize: CGSize(width: 200, height: 100),
            menuFrame: CGRect(x: 20, y: 0, width: 360, height: 500),
            screen: CGRect(x: 0, y: 0, width: 1440, height: 900), backingScale: 2))
        #expect(small.imageRect.size == CGSize(width: 100, height: 50))
    }

    @Test func previewDoesNotActivateAndHidesForTextAndMenuClose() throws {
        let _ = NSApplication.shared
        let controller = HistoryMenuController()
        let image = try stripedImage()
        let imageItem = item(kind: .image)
        let textItem = item(kind: .text)
        controller.imageProvider = { _ in image }
        controller.setItems([imageItem, textItem])
        controller.prepareForDisplay()
        let window = NSWindow(contentRect: CGRect(x: 50, y: 100, width: 360, height: 500),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = controller.menu.items.first?.view
        let imageRow = try #require(controller.menu.items.first { $0.representedObject as? String == imageItem.id.uuidString })
        let textRow = try #require(controller.menu.items.first { $0.representedObject as? String == textItem.id.uuidString })
        controller.menu(controller.menu, willHighlight: imageRow)
        #expect(controller.previewedImageID == imageItem.id)
        controller.menu(controller.menu, willHighlight: textRow)
        #expect(controller.previewedImageID == nil)
        controller.menu(controller.menu, willHighlight: imageRow)
        controller.menuDidClose(controller.menu)
        #expect(controller.previewedImageID == nil)

        let preview = HistoryImagePreviewController()
        let screen = try #require(NSScreen.main)
        preview.show(image: image, itemID: imageItem.id, menuFrame: window.frame, screen: screen)
        defer { preview.hide() }
        let panel = try #require(preview.window)
        #expect(!panel.canBecomeKey && !panel.canBecomeMain && panel.ignoresMouseEvents)
        let view = try #require(panel.contentView as? HistoryImagePreviewView)
        #expect(view.image?.width == 512)
        // At native display scale alternating one-pixel stripes remain crisp.
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let scale = panel.backingScaleFactor
        let x0 = Int((view.imageRect.minX * scale).rounded())
        let y = bitmap.pixelsHigh - Int((view.imageRect.midY * scale).rounded())
        var contrasted = 0
        for x in (x0 + 2)..<(x0 + 500) {
            let a = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
            let b = try #require(bitmap.colorAt(x: x + 1, y: y)?.usingColorSpace(.deviceRGB))
            if abs(a.redComponent - b.redComponent) > 0.8 { contrasted += 1 }
        }
        #expect(contrasted > 450)
    }

    private func keyEvent(code: UInt16, flags: NSEvent.ModifierFlags) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
            timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
            isARepeat: false, keyCode: code))
    }

    private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    private func item(kind: ClipItemKind) -> ClipItem {
        ClipItem(id: UUID(), kind: kind, createdAt: Date(), sourceAppName: nil, contentHash: UUID().uuidString,
                 text: kind == .text ? "Text has no preview" : nil, imageFileName: nil,
                 imagePixelWidth: kind == .image ? 512 : nil, imagePixelHeight: kind == .image ? 128 : nil)
    }

    private func stripedImage() throws -> NSImage {
        let context = try #require(CGContext(data: nil, width: 512, height: 128, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        for x in 0..<512 {
            context.setFillColor(CGColor(gray: x.isMultiple(of: 2) ? 0 : 1, alpha: 1))
            context.fill(CGRect(x: x, y: 0, width: 1, height: 128))
        }
        return NSImage(cgImage: try #require(context.makeImage()), size: CGSize(width: 512, height: 128))
    }
}
