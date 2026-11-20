//
//  CaptureEngine.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 29.01.26.
//

import Foundation
import ScreenCaptureKit
import OSLog

/// Delegate protocol for receiving capture events (non-sample buffer events)
@MainActor
protocol CaptureEngineDelegate: AnyObject {
    func captureEngine(_ engine: CaptureEngine, didUpdateFilter filter: SCContentFilter)
    func captureEngine(_ engine: CaptureEngine, didStopWithError error: Error?)
    func captureEngine(_ engine: CaptureEngine, systemAudioDidFailWith error: Error?)
    func captureEngineDidCancelPicker(_ engine: CaptureEngine)
    func captureEngine(_ engine: CaptureEngine, presenterOverlayDidChange isActive: Bool)
}

/// Protocol for receiving sample buffers - called synchronously on capture queue
protocol CaptureEngineSampleBufferDelegate: AnyObject, Sendable {
    nonisolated func captureEngine(_ engine: CaptureEngine, didOutputVideoSampleBuffer sampleBuffer: CMSampleBuffer)
    nonisolated func captureEngine(_ engine: CaptureEngine, didOutputAudioSampleBuffer sampleBuffer: CMSampleBuffer)
    nonisolated func captureEngine(_ engine: CaptureEngine, didOutputMicrophoneSampleBuffer sampleBuffer: CMSampleBuffer)
}

/// Service responsible for managing ScreenCaptureKit capture streams
@MainActor
final class CaptureEngine: NSObject {

    // MARK: - Properties

    weak var delegate: CaptureEngineDelegate?

    /// Sample buffer delegate - accessed from capture queue, hence nonisolated
    /// The delegate must be set before starting capture and not changed during capture
    nonisolated(unsafe) weak var sampleBufferDelegate: CaptureEngineSampleBufferDelegate?

    private(set) var contentFilter: SCContentFilter?
    private(set) var isCapturing = false
    private(set) var isPresenterOverlayActive = false

    private var stream: SCStream?
    private let systemAudioStream = SystemAudioStream()
    private let picker = SCContentSharingPicker.shared
    private let contentFilterService = ContentFilterService()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture", category: "CaptureEngine")

    // Queues for sample buffer handling
    private let videoSampleQueue = DispatchQueue(label: "com.bettercapture.videoSampleQueue", qos: .userInteractive)
    private let audioSampleQueue = DispatchQueue(label: "com.bettercapture.audioSampleQueue", qos: .userInteractive)
    private let microphoneSampleQueue = DispatchQueue(label: "com.bettercapture.microphoneSampleQueue", qos: .userInteractive)

    /// Whether this engine observes the shared content sharing picker
    private let usesPicker: Bool

    // MARK: - Initialization

    /// - Parameter usesPicker: Whether content is chosen with the system picker. Engines that
    ///   are handed their content directly, such as for command-line recordings, must not
    ///   observe the shared picker, or they would pick up the menu bar's selections.
    init(usesPicker: Bool = true) {
        self.usesPicker = usesPicker
        super.init()
        if usesPicker {
            setupPicker()
        }
    }

    // MARK: - Picker Management

    /// Sets up the content sharing picker
    private func setupPicker() {
        picker.add(self)
        // Don't activate picker at startup to avoid triggering camera indicator
        // It will be activated when presentPicker() is called

        var config = SCContentSharingPickerConfiguration()
        config.allowsChangingSelectedContent = true

        // Enable all picker modes including display selection
        config.allowedPickerModes = [.singleDisplay, .singleWindow, .singleApplication]

        // Exclude this app from capture
        if let bundleID = Bundle.main.bundleIdentifier {
            config.excludedBundleIDs = [bundleID]
        }

        picker.defaultConfiguration = config
    }

    /// Presents the system content sharing picker
    /// - Note: The picker window should appear above all other windows, but may sometimes
    ///         appear behind the menu bar popover depending on window levels. If this occurs,
    ///         the user can click outside the menu bar to dismiss it before presenting the picker.
    func presentPicker() {
        // Activate picker when it's actually needed
        picker.isActive = true
        picker.present()
    }

    // MARK: - Stream Management

    /// Starts capturing with the current content filter
    /// - Parameters:
    ///   - settings: The settings store containing capture configuration
    ///   - videoSize: The dimensions for the captured video
    ///   - sourceRect: Optional rectangle for area selection (display points, top-left origin)
    func startCapture(with settings: SettingsStore, videoSize: CGSize, sourceRect: CGRect? = nil) async throws {
        guard let filter = contentFilter else {
            throw CaptureError.noContentFilterSelected
        }

        try await verifyPermissions(for: settings)

        // A display selected before it was disconnected still yields a usable filter, but the
        // stream never delivers frames. Fail fast instead of recording without a video track.
        guard await contentFilterService.isSelectedDisplayConnected(filter) else {
            throw CaptureError.selectedDisplayDisconnected
        }

        // Apply content filter settings (wallpaper, dock, menu bar)
        logger.info("Applying content filter settings...")
        let filteredContent = try await contentFilterService.applySettings(to: filter, settings: settings)
        logger.info("Content filter applied, creating stream...")

        // A stream's audio is scoped by its video filter, so a window or application capture
        // would only record the selected app's audio. Those styles get a dedicated
        // full-display audio stream instead; display captures already hear everything.
        let captureStyle = CaptureFilterStyle(filteredContent)
        let needsDedicatedAudioStream = settings.captureSystemAudio && captureStyle != .display

        let streamConfig = createStreamConfiguration(
            from: settings,
            contentSize: videoSize,
            sourceRect: sourceRect,
            isWindowCapture: captureStyle == .window,
            capturesAudio: settings.captureSystemAudio && !needsDedicatedAudioStream
        )

        stream = SCStream(filter: filteredContent, configuration: streamConfig, delegate: self)

        guard let stream else {
            throw CaptureError.failedToCreateStream
        }

        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoSampleQueue)
        logger.info("Added screen output")

        if settings.captureSystemAudio && !needsDedicatedAudioStream {
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioSampleQueue)
            logger.info("Added system audio output")
        }

        // The microphone is device-scoped rather than filter-scoped, so it always stays on
        // the main stream.
        if settings.captureMicrophone {
            try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: microphoneSampleQueue)
            logger.info("Added microphone output (device: \(settings.selectedMicrophoneID ?? "default"))")
        }

        logger.info("Stream config - capturesAudio: \(settings.captureSystemAudio), captureMicrophone: \(settings.captureMicrophone)")
        logger.info("Starting stream capture...")
        try await stream.startCapture()
        logger.info("Stream capture started successfully")
        isCapturing = true

        if needsDedicatedAudioStream {
            await startSystemAudioStream()
        }

        logger.info("Capture started successfully")
    }

    /// Ensures the permissions the requested capture needs are granted, prompting if they are not
    /// - Parameter settings: The settings store containing capture configuration
    private func verifyPermissions(for settings: SettingsStore) async throws {
        let hasPermission = contentFilterService.hasScreenRecordingPermission()
        logger.info("Screen recording permission check: \(hasPermission)")

        guard hasPermission else {
            // Request permission - this will open the system prompt or System Settings
            contentFilterService.requestScreenRecordingPermission()
            throw CaptureError.screenRecordingPermissionDenied
        }

        guard settings.captureMicrophone else { return }

        let hasMicPermission = contentFilterService.hasMicrophonePermission()
        logger.info("Microphone permission check: \(hasMicPermission)")

        if !hasMicPermission, await !contentFilterService.requestMicrophonePermission() {
            throw CaptureError.microphonePermissionDenied
        }
    }

    /// Starts the dedicated system audio stream, keeping the recording alive if it fails
    private func startSystemAudioStream() async {
        do {
            try await systemAudioStream.start(output: self, delegate: self, sampleQueue: audioSampleQueue)
        } catch {
            logger.error("Failed to start system audio stream: \(error.localizedDescription)")
            delegate?.captureEngine(self, systemAudioDidFailWith: error)
        }
    }

    /// Stops the current capture stream
    func stopCapture() async throws {
        await systemAudioStream.stop()

        guard let runningStream = stream, isCapturing else { return }

        // Detach before suspending, so a second caller cannot stop the same stream again
        stream = nil
        isCapturing = false
        isPresenterOverlayActive = false

        do {
            try await runningStream.stopCapture()
        } catch let error as NSError where error.code == SCStreamError.Code.attemptToStopStreamState.rawValue {
            // The stream had already stopped on its own, which is what was wanted
            logger.debug("Stream was already stopped")
        }

        logger.info("Capture stopped successfully")
    }

    /// Updates the content filter for an active stream
    func updateFilter(_ filter: SCContentFilter) async throws {
        contentFilter = filter

        if let stream, isCapturing {
            try await stream.updateContentFilter(filter)
            logger.info("Content filter updated")
        }
    }

    // MARK: - Configuration

    /// Creates an SCStreamConfiguration from user settings
    /// - Parameters:
    ///   - settings: The settings store containing capture configuration
    ///   - contentSize: The output dimensions for the captured video
    ///   - sourceRect: Optional rectangle for area selection (display points, top-left origin)
    ///   - isWindowCapture: Whether the filter captures a single window
    ///   - capturesAudio: Whether this stream carries system audio, or a dedicated one does
    private func createStreamConfiguration(
        from settings: SettingsStore,
        contentSize: CGSize,
        sourceRect: CGRect? = nil,
        isWindowCapture: Bool = false,
        capturesAudio: Bool = false
    ) -> SCStreamConfiguration {
        let config: SCStreamConfiguration

        switch settings.hdrPreset {
        case .hdr10PreservedSDR:
            if #available(macOS 26, *) {
                config = SCStreamConfiguration(preset: .captureHDRRecordingPreservedSDRHDR10)
            } else {
                // Unreachable — hdrPreset only returns .hdr10PreservedSDR on macOS 26+
                config = SCStreamConfiguration()
            }
            // Only override pixel format for ProRes, which needs different
            // chroma subsampling (4:2:2 / 16-bit RGBA). For HEVC, let the
            // preset's own pixel format stand to preserve EDR headroom.
            if settings.videoCodec == .proRes422 || settings.videoCodec == .proRes4444 {
                config.pixelFormat = settings.videoCodec.hdrPixelFormat
            }

        case .hdr10Manual:
            // Manually replicate the HDR10 recording preset for pre-macOS 26.
            // Do NOT set colorSpaceName — it triggers an internal CoreGraphics
            // tone-mapping pass that destructively clips EDR headroom.
            config = SCStreamConfiguration()
            config.captureDynamicRange = .hdrCanonicalDisplay
            config.pixelFormat = settings.videoCodec.hdrPixelFormat

        case .sdr:
            config = SCStreamConfiguration()
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.captureDynamicRange = .SDR
        }

        // Set output dimensions - required for proper capture
        config.width = Int(contentSize.width)
        config.height = Int(contentSize.height)

        // Independent window capture is the one mode where ScreenCaptureKit does not resize content
        // to the configured dimensions on its own: it renders the window at its natural pixel size
        // in the top-left corner and leaves the rest of the buffer blank. Scaling to fit keeps the
        // content filling the frame even if the dimensions above are ever wrong again, rather than
        // silently baking a crop into the recording.
        if isWindowCapture {
            config.scalesToFit = true
        }

        // Set source rect for area selection (only works with display captures)
        if let sourceRect {
            config.sourceRect = sourceRect
            logger.info("Source rect set: \(sourceRect.origin.x),\(sourceRect.origin.y) \(sourceRect.width)x\(sourceRect.height)")
        }

        // Frame rate. `effectiveFrameRate` resolves `.native` to 60, matching the
        // constant frame rate grid AssetWriter snaps the video track to.
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(settings.frameRate.effectiveFrameRate))

        // AssetWriter holds on to the two most recent frames so it can repeat the last
        // one across a stall. The default queue depth of 3 would leave ScreenCaptureKit
        // just one spare buffer, so give it more headroom.
        config.queueDepth = 8

        // Cursor visibility
        config.showsCursor = settings.showCursor

        // Window shadows
        config.ignoreShadowsDisplay = !settings.showWindowShadows
        config.ignoreShadowsSingleWindow = !settings.showWindowShadows

        // System audio settings
        config.capturesAudio = capturesAudio
        config.sampleRate = 48000
        config.channelCount = 2

        // Microphone settings - requires full TCC screen recording permission
        config.captureMicrophone = settings.captureMicrophone
        if let microphoneID = settings.selectedMicrophoneID {
            config.microphoneCaptureDeviceID = microphoneID
        }

        return config
    }

    /// Clears the current content filter selection
    func clearSelection() {
        contentFilter = nil
    }

    /// Deactivates the content sharing picker to remove camera indicator
    func deactivatePicker() {
        picker.isActive = false
        logger.info("Picker deactivated")
    }

    deinit {
        if usesPicker {
            picker.remove(self)
        }
    }
}

// MARK: - SCContentSharingPickerObserver

extension CaptureEngine: SCContentSharingPickerObserver {

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { @MainActor in
            self.contentFilter = filter
            self.delegate?.captureEngine(self, didUpdateFilter: filter)
            logger.info("Content filter updated from picker")

            // Deactivate picker after content selection to remove camera indicator
            picker.isActive = false
        }
    }

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor in
            // Clear the content filter when picker is cancelled or "Stop Sharing" is clicked
            self.contentFilter = nil

            self.delegate?.captureEngineDidCancelPicker(self)
            logger.info("Picker cancelled, content filter cleared")

            // Deactivate picker after cancellation to remove camera indicator
            picker.isActive = false
        }
    }

    nonisolated func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        Task { @MainActor in
            logger.error("Picker failed to start: \(error.localizedDescription)")
        }
    }
}

// MARK: - SCStreamDelegate

extension CaptureEngine: SCStreamDelegate {

    nonisolated func stream(_ stream: SCStream, didStopWithError error: any Error) {
        // Resolve the identity here: SCStream is not Sendable and cannot cross to the main actor.
        let isSystemAudioStream = systemAudioStream.owns(stream)

        Task { @MainActor in
            guard !isSystemAudioStream else {
                // Losing system audio must not tear down the video recording
                self.systemAudioStream.handleStoppedExternally()
                self.delegate?.captureEngine(self, systemAudioDidFailWith: error)
                logger.error("System audio stream stopped with error: \(error.localizedDescription)")
                return
            }

            self.isCapturing = false
            self.stream = nil
            await self.systemAudioStream.stop()
            self.delegate?.captureEngine(self, didStopWithError: error)
            logger.error("Stream stopped with error: \(error.localizedDescription)")
        }
    }

    nonisolated func outputVideoEffectDidStart(for stream: SCStream) {
        Task { @MainActor in
            self.isPresenterOverlayActive = true
            self.delegate?.captureEngine(self, presenterOverlayDidChange: true)
            logger.info("Presenter Overlay started")
        }
    }

    nonisolated func outputVideoEffectDidStop(for stream: SCStream) {
        Task { @MainActor in
            self.isPresenterOverlayActive = false
            self.delegate?.captureEngine(self, presenterOverlayDidChange: false)
            logger.info("Presenter Overlay stopped")
        }
    }
}

// MARK: - SCStreamOutput

extension CaptureEngine: SCStreamOutput {

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }

        // Call sample buffer delegate synchronously on the capture queue
        // to ensure the buffer remains valid during processing
        switch type {
        case .screen:
            sampleBufferDelegate?.captureEngine(self, didOutputVideoSampleBuffer: sampleBuffer)
        case .audio:
            sampleBufferDelegate?.captureEngine(self, didOutputAudioSampleBuffer: sampleBuffer)
        case .microphone:
            sampleBufferDelegate?.captureEngine(self, didOutputMicrophoneSampleBuffer: sampleBuffer)
        @unknown default:
            break
        }
    }
}

// MARK: - Errors

enum CaptureError: LocalizedError, Equatable {
    case noContentFilterSelected
    case failedToCreateStream
    case captureAlreadyRunning
    case screenRecordingPermissionDenied
    case microphonePermissionDenied
    case cameraPermissionDenied
    case selectedDisplayDisconnected

    var errorDescription: String? {
        switch self {
        case .noContentFilterSelected:
            return "No content has been selected for capture. Please use the picker to select a window or display."
        case .failedToCreateStream:
            return "Failed to create the capture stream."
        case .captureAlreadyRunning:
            return "A capture session is already in progress."
        case .screenRecordingPermissionDenied:
            return "Screen recording permission is required. Please grant permission in System Settings → Privacy & Security → Screen Recording."
        case .microphonePermissionDenied:
            return "Microphone permission is required. Please grant permission in System Settings → Privacy & Security → Microphone."
        case .cameraPermissionDenied:
            return "Camera permission is required for Presenter Overlay. Please grant permission in System Settings → Privacy & Security → Camera, or turn off Presenter Overlay."
        case .selectedDisplayDisconnected:
            return "The selected display is no longer connected. Please select the content to capture again."
        }
    }
}
