import AppKit
import CoreMedia
import ScreenCaptureKit
import VideoToolbox

@available(macOS 14.0, *)
@MainActor
final class LivePinSession: NSObject, SCStreamDelegate {
    var onClose: (() -> Void)?
    private let filter: SCContentFilter
    private let panel: PinnedLivePanelController
    private let output: LivePinFrameOutput
    private var stream: SCStream?
    private var transitionTask: Task<Void, Never>?
    private var resolutionTask: Task<Void, Never>?
    private var capturePixelSize: CGSize = .zero
    private var pendingPixelSize: CGSize?
    private var isClosed = false
    private var isPaused = false
    private var isUnavailable = false
    private var hasFailed = false

    init(filter: SCContentFilter, appearance: PinAppearanceSettings) {
        self.filter = filter
        self.panel = PinnedLivePanelController(sourceSize: filter.contentRect.size)
        self.output = LivePinFrameOutput(fallbackPointSize: filter.contentRect.size)
        super.init()
        panel.applyAppearance(settings: appearance)
        panel.onClose = { [weak self] in self?.close() }
        panel.onPauseRequest = { [weak self] in self?.togglePause() }
        output.onFrame = { [weak self] frame in
            guard let self, !self.isClosed, !self.hasFailed else { return }
            self.requestResolution(frame.nativePixelSize)
            // Never magnify a frame that the capture server already reduced.
            // Keep the last native frame while the stream catches up to resize.
            guard frame.isNativeResolution else { return }
            self.panel.setFrame(frame)
            guard !self.isPaused else { return }
            let wasUnavailable = self.isUnavailable
            self.isUnavailable = false
            if wasUnavailable, self.transitionTask == nil {
                self.panel.showStatus(nil)
            }
        }
        output.onUnavailable = { [weak self] in self?.sourceUnavailable() }
    }

    func start() {
        panel.showWindow(nil)
        panel.window?.center()
        panel.window?.orderFrontRegardless()
        panel.showStatus("Starting Live Pin…")
        transitionTask = Task { [weak self] in
            guard let self else { return }
            do {
                self.capturePixelSize = self.pixelSize(for: self.filter.contentRect.size)
                let configuration = self.configuration(for: self.capturePixelSize)
                let stream = SCStream(filter: self.filter, configuration: configuration, delegate: self)
                self.stream = stream
                try stream.addStreamOutput(self.output, type: .screen, sampleHandlerQueue: self.output.queue)
                try await stream.startCapture()
                if !self.isClosed {
                    self.panel.setPauseState(paused: false, enabled: true)
                    self.showRunningStatus()
                }
            } catch {
                if !self.isClosed { self.captureFailed(error) }
            }
            self.transitionTask = nil
            self.updateResolutionIfNeeded()
        }
    }

    private func pixelSize(for pointSize: CGSize) -> CGSize {
        let scale = max(1, CGFloat(filter.pointPixelScale))
        return LivePinGeometry.capturePixelSize(for: pointSize, pixelScale: scale)
    }

    private func configuration(for pixelSize: CGSize) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.width = Int(pixelSize.width)
        configuration.height = Int(pixelSize.height)
        configuration.captureResolution = .best
        configuration.scalesToFit = false
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 15)
        configuration.queueDepth = 2
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        // VTCreateCGImageFromCVPixelBuffer uses sRGB for RGB buffers. Request
        // matching pixel data instead of assigning sRGB to display-profile RGB.
        configuration.colorSpaceName = CGColorSpace.sRGB
        configuration.showsCursor = false
        configuration.capturesAudio = false
        configuration.ignoreShadowsSingleWindow = true
        configuration.streamName = "ClipPin Live Pin"
        return configuration
    }

    private func requestResolution(_ pixelSize: CGSize) {
        let next = LivePinGeometry.capturePixelSize(for: pixelSize, pixelScale: 1)
        guard next != capturePixelSize else { return }
        pendingPixelSize = next
        updateResolutionIfNeeded()
    }

    private func updateResolutionIfNeeded() {
        guard !isClosed, !isPaused, !hasFailed, transitionTask == nil,
              resolutionTask == nil, pendingPixelSize != nil, let stream else { return }
        resolutionTask = Task { [weak self] in
            guard let self else { return }
            while !self.isClosed, !self.isPaused, !self.hasFailed, self.transitionTask == nil,
                  let next = self.pendingPixelSize {
                self.pendingPixelSize = nil
                guard next != self.capturePixelSize else { continue }
                do {
                    try await stream.updateConfiguration(self.configuration(for: next))
                    self.capturePixelSize = next
                } catch {
                    if !self.isClosed { self.captureFailed(error) }
                    break
                }
            }
            self.resolutionTask = nil
        }
    }

    private func togglePause() {
        guard !isClosed, !hasFailed, transitionTask == nil, let stream else { return }
        let shouldPause = !isPaused
        panel.setPauseState(paused: isPaused, enabled: false)
        panel.showStatus(shouldPause ? "Pausing…" : "Resuming…")
        transitionTask = Task { [weak self] in
            guard let self else { return }
            await self.resolutionTask?.value
            do {
                if shouldPause {
                    try await stream.stopCapture()
                } else {
                    try await stream.startCapture()
                }
                guard !self.isClosed else {
                    self.transitionTask = nil
                    return
                }
                self.isPaused = shouldPause
                self.panel.setPauseState(paused: shouldPause, enabled: true)
                if shouldPause { self.panel.showStatus("Paused") }
                else { self.showRunningStatus() }
            } catch {
                if !self.isClosed { self.captureFailed(error) }
            }
            self.transitionTask = nil
            self.updateResolutionIfNeeded()
        }
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        output.invalidate()
        let pending = transitionTask
        let pendingResolution = resolutionTask
        let stream = self.stream
        self.stream = nil
        // Wait for an in-flight start/resume before stopping, so a closed pin
        // cannot accidentally restart its stream after stopCapture completes.
        Task {
            await pending?.value
            await pendingResolution?.value
            try? await stream?.stopCapture()
        }
        panel.onClose = nil
        panel.close()
        onClose?()
        onClose = nil
    }

    private func sourceUnavailable() {
        guard !isClosed, !isPaused, !hasFailed else { return }
        isUnavailable = true
        if transitionTask == nil { showRunningStatus() }
    }

    private func showRunningStatus() {
        panel.showStatus(isUnavailable ? "Window unavailable · Restore the source window"
                         : "Original size · Drag to pan · ⌘-drag to move · Option-drag to crop", temporary: !isUnavailable)
    }

    private func captureFailed(_ error: Error) {
        hasFailed = true
        output.invalidate()
        panel.setPauseState(paused: false, enabled: false)
        panel.showStatus("Capture stopped · Close this pin and choose the window again")
        panel.showErrorDetails(error.localizedDescription)
        NSLog("ClipPin Live Pin stopped: \(error.localizedDescription)")
        if let stream { Task { try? await stream.stopCapture() } }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.transitionTask?.value
            guard !self.isClosed, !self.isPaused, !self.hasFailed,
                  self.stream === stream else { return }
            self.captureFailed(error)
        }
    }

    nonisolated func streamDidBecomeInactive(_ stream: SCStream) {
        Task { @MainActor [weak self] in
            guard self?.stream === stream else { return }
            self?.sourceUnavailable()
        }
    }

    nonisolated func streamDidBecomeActive(_ stream: SCStream) {
        Task { @MainActor [weak self] in
            guard let self, self.stream === stream, !self.isClosed, !self.isPaused,
                  !self.hasFailed else { return }
            self.isUnavailable = false
            self.panel.showStatus(nil)
        }
    }
}

/// Converts frames off the UI thread; one pending image bounds UI backpressure.
@available(macOS 14.0, *)
private final class LivePinFrameOutput: NSObject, SCStreamOutput {
    let queue = DispatchQueue(label: "com.clippin.livepin.frames", qos: .userInitiated)
    var onFrame: (@MainActor (LivePinFrame) -> Void)?
    var onUnavailable: (@MainActor () -> Void)?
    private let lock = NSLock()
    private var isValid = true
    private var pendingFrame: LivePinFrame?
    private var pendingUnavailable = false
    private var deliveryScheduled = false
    private let fallbackPointSize: CGSize
    #if DEBUG
    private var didLogGeometry = false
    #endif

    init(fallbackPointSize: CGSize) {
        self.fallbackPointSize = fallbackPointSize
        super.init()
    }

    func invalidate() {
        lock.lock()
        isValid = false
        pendingFrame = nil
        pendingUnavailable = false
        lock.unlock()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, buffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
              let info = attachments.first,
              let rawStatus = info[.status] as? Int,
              let status = SCFrameStatus(rawValue: rawStatus) else { return }
        if status == .suspended || status == .blank || status == .stopped {
            enqueue(frame: nil, unavailable: true)
            return
        }
        guard status == .complete, let pixels = buffer.imageBuffer else { return }
        autoreleasepool {
            var rawImage: CGImage?
            guard VTCreateCGImageFromCVPixelBuffer(pixels, options: nil, imageOut: &rawImage) == noErr,
                  let image = rawImage else { return }
            let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
            var rect = bounds
            var pointSize = fallbackPointSize
            let contentScale = (info[.contentScale] as? NSNumber)?.doubleValue ?? 1
            var nativePixelSize = bounds.size
            if let dictionary = info[.contentRect] as? [String: Any],
               let content = CGRect(dictionaryRepresentation: dictionary as CFDictionary) {
                let scale = (info[.scaleFactor] as? NSNumber)?.doubleValue ?? 1
                let pixelRect = content.applying(CGAffineTransform(scaleX: scale, y: scale))
                // Both CGImage cropping and this metadata use a top-left origin.
                let clipped = pixelRect.integral.intersection(bounds)
                if !clipped.isNull, !clipped.isEmpty { rect = clipped }
                if let size = LivePinGeometry.sourcePointSize(pixelSize: pixelRect.size,
                        pixelScale: CGFloat(scale), contentScale: CGFloat(contentScale)) {
                    pointSize = size
                    // Native dimensions are integral; metadata ratios have
                    // float rounding error, so do not ceil 292.000002 to 293.
                    nativePixelSize = CGSize(width: (size.width * CGFloat(scale)).rounded(),
                                             height: (size.height * CGFloat(scale)).rounded())
                }
            }
            // The on-screen window bounds remain in points even if the output
            // surface was scaled to fit during a source-window resize.
            if let dictionary = info[.screenRect] as? [String: Any],
               let screenRect = CGRect(dictionaryRepresentation: dictionary as CFDictionary),
               screenRect.width > 0, screenRect.height > 0 { pointSize = screenRect.size }
            #if DEBUG
            if !didLogGeometry {
                didLogGeometry = true
                NSLog("ClipPin Live Pin geometry: buffer=%dx%d content=%.0fx%.0f source=%.0fx%.0f scale=%@ contentScale=%@",
                      CVPixelBufferGetWidth(pixels), CVPixelBufferGetHeight(pixels), rect.width, rect.height,
                      pointSize.width, pointSize.height,
                      String(describing: info[.scaleFactor]), String(describing: info[.contentScale]))
            }
            #endif
            guard let frame = image.cropping(to: rect) else { return }
            enqueue(frame: LivePinFrame(image: frame, pointSize: pointSize,
                nativePixelSize: nativePixelSize, contentScale: CGFloat(contentScale)), unavailable: false)
        }
    }

    private func enqueue(frame: LivePinFrame?, unavailable: Bool) {
        lock.lock()
        guard isValid else { lock.unlock(); return }
        pendingFrame = frame
        pendingUnavailable = unavailable
        let shouldSchedule = !deliveryScheduled
        deliveryScheduled = true
        lock.unlock()
        if shouldSchedule {
            DispatchQueue.main.async { [weak self] in self?.deliver() }
        }
    }

    @MainActor
    private func deliver() {
        lock.lock()
        let frame = pendingFrame
        let unavailable = pendingUnavailable
        let valid = isValid
        pendingFrame = nil
        pendingUnavailable = false
        deliveryScheduled = false
        lock.unlock()
        guard valid else { return }
        if let frame { onFrame?(frame) }
        else if unavailable { onUnavailable?() }
    }
}
