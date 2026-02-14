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
    func captureEngineDidCancelPicker(_ engine: CaptureEngine)
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

    private var stream: SCStream?
    private let picker = SCContentSharingPicker.shared
    private let contentFilterService = ContentFilterService()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture", category: "CaptureEngine")

    // Queues for sample buffer handling
    private let videoSampleQueue = DispatchQueue(label: "com.bettercapture.videoSampleQueue", qos: .userInteractive)
    private let audioSampleQueue = DispatchQueue(label: "com.bettercapture.audioSampleQueue", qos: .userInteractive)
    private let microphoneSampleQueue = DispatchQueue(label: "com.bettercapture.microphoneSampleQueue", qos: .userInteractive)

    // MARK: - Initialization

    override init() {
        super.init()
        setupPicker()
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

        // Check for screen recording permission before starting capture
        let hasPermission = contentFilterService.hasScreenRecordingPermission()
        logger.info("Screen recording permission check: \(hasPermission)")

        guard hasPermission else {
            // Request permission - this will open the system prompt or System Settings
            contentFilterService.requestScreenRecordingPermission()
            throw CaptureError.screenRecordingPermissionDenied
        }

        // Check for microphone permission if microphone capture is enabled
        if settings.captureMicrophone {
            let hasMicPermission = contentFilterService.hasMicrophonePermission()
            logger.info("Microphone permission check: \(hasMicPermission)")

            if !hasMicPermission {
                let granted = await contentFilterService.requestMicrophonePermission()
                if !granted {
                    throw CaptureError.microphonePermissionDenied
                }
            }
        }

        // Apply content filter settings (wallpaper, dock, menu bar)
        logger.info("Applying content filter settings...")
        let filteredContent = try await contentFilterService.applySettings(to: filter, settings: settings)
        logger.info("Content filter applied, creating stream...")

        let streamConfig = createStreamConfiguration(from: settings, contentSize: videoSize, sourceRect: sourceRect)

        stream = SCStream(filter: filteredContent, configuration: streamConfig, delegate: self)

        guard let stream else {
            throw CaptureError.failedToCreateStream
        }

        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoSampleQueue)
        logger.info("Added screen output")

        if settings.captureSystemAudio {
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioSampleQueue)
            logger.info("Added system audio output")
        }

        if settings.captureMicrophone {
            try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: microphoneSampleQueue)
            logger.info("Added microphone output (device: \(settings.selectedMicrophoneID ?? "default"))")
        }

        logger.info("Stream config - capturesAudio: \(settings.captureSystemAudio), captureMicrophone: \(settings.captureMicrophone)")
        logger.info("Starting stream capture...")
        try await stream.startCapture()
        logger.info("Stream capture started successfully")
        isCapturing = true

        logger.info("Capture started successfully")
    }

    /// Stops the current capture stream
    func stopCapture() async throws {
        guard let stream, isCapturing else { return }

        try await stream.stopCapture()
        self.stream = nil
        isCapturing = false

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
    private func createStreamConfiguration(from settings: SettingsStore, contentSize: CGSize, sourceRect: CGRect? = nil) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()

        // Set output dimensions - required for proper capture
        config.width = Int(contentSize.width)
        config.height = Int(contentSize.height)

        // Set source rect for area selection (only works with display captures)
        if let sourceRect {
            config.sourceRect = sourceRect
            logger.info("Source rect set: \(sourceRect.origin.x),\(sourceRect.origin.y) \(sourceRect.width)x\(sourceRect.height)")
        }

        // Frame rate - native uses display sync (1/120 timescale)
        if settings.frameRate == .native {
            config.minimumFrameInterval = CMTime(value: 1, timescale: 120)
        } else {
            config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(settings.frameRate.rawValue))
        }

        // Cursor visibility
        config.showsCursor = settings.showCursor

        // System audio settings
        config.capturesAudio = settings.captureSystemAudio
        config.sampleRate = 48000
        config.channelCount = 2

        // Microphone settings - requires full TCC screen recording permission
        config.captureMicrophone = settings.captureMicrophone
        if let microphoneID = settings.selectedMicrophoneID {
            config.microphoneCaptureDeviceID = microphoneID
        }

        // Configure pixel format and dynamic range based on HDR setting
        if settings.captureHDR && settings.videoCodec.supportsHDR {
            // HDR: Use 10-bit YCbCr format with HDR dynamic range
            config.pixelFormat = kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
            config.captureDynamicRange = .hdrLocalDisplay
        } else {
            // SDR: Use 8-bit BGRA format
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.captureDynamicRange = .SDR
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
        picker.remove(self)
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
        Task { @MainActor in
            self.isCapturing = false
            self.stream = nil
            self.delegate?.captureEngine(self, didStopWithError: error)
            logger.error("Stream stopped with error: \(error.localizedDescription)")
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

enum CaptureError: LocalizedError {
    case noContentFilterSelected
    case failedToCreateStream
    case captureAlreadyRunning
    case screenRecordingPermissionDenied
    case microphonePermissionDenied

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
        }
    }
}
