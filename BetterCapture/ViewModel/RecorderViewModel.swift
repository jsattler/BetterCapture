//
//  RecorderViewModel.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 29.01.26.
//

import Foundation
import ScreenCaptureKit
import AppKit
import OSLog

/// The main view model managing recording state and coordination between services
@MainActor
@Observable
final class RecorderViewModel {

    // MARK: - Recording State

    enum RecordingState {
        case idle
        case recording
        case stopping
    }

    // MARK: - Published Properties

    private(set) var state: RecordingState = .idle
    private(set) var recordingDuration: TimeInterval = 0
    private(set) var lastError: Error?
    private(set) var selectedContentFilter: SCContentFilter?

    /// The source rectangle for area selection (in display points, top-left origin)
    private(set) var selectedSourceRect: CGRect?

    /// Whether the current selection is an area selection (as opposed to a picker selection)
    var isAreaSelection: Bool {
        selectedSourceRect != nil
    }

    var isRecording: Bool {
        state == .recording
    }

    var canStartRecording: Bool {
        selectedContentFilter != nil && state == .idle
    }

    var hasContentSelected: Bool {
        selectedContentFilter != nil
    }

    var formattedDuration: String {
        let hours = Int(recordingDuration) / 3600
        let minutes = (Int(recordingDuration) % 3600) / 60
        let seconds = Int(recordingDuration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    // MARK: - Dependencies

    let settings: SettingsStore
    let audioDeviceService: AudioDeviceService
    let previewService: PreviewService
    let notificationService: NotificationService
    let permissionService: PermissionService
    private let captureEngine: CaptureEngine
    private let assetWriter: AssetWriter

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture", category: "RecorderViewModel")

    // MARK: - Private Properties

    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var videoSize: CGSize = .zero
    private let areaSelectionOverlay = AreaSelectionOverlay()

    // MARK: - Initialization

    init() {
        self.settings = SettingsStore()
        self.audioDeviceService = AudioDeviceService()
        self.previewService = PreviewService()
        self.notificationService = NotificationService()
        self.permissionService = PermissionService()
        self.captureEngine = CaptureEngine()
        self.assetWriter = AssetWriter()

        captureEngine.delegate = self
        captureEngine.sampleBufferDelegate = assetWriter
        previewService.delegate = self
    }

    // MARK: - Permission Methods

    /// Requests required permissions on app launch
    /// Only requests microphone permission if microphone capture is enabled
    func requestPermissionsOnLaunch() async {
        await permissionService.requestPermissions(includeMicrophone: settings.captureMicrophone)
    }

    /// Refreshes the current permission states
    func refreshPermissions() {
        permissionService.updatePermissionStates()
    }

    // MARK: - Public Methods

    /// Presents the system content sharing picker
    func presentPicker() {
        captureEngine.presentPicker()
    }

    /// Presents the area selection overlay on the display under the cursor
    func presentAreaSelection() async {
        guard let result = await areaSelectionOverlay.present() else {
            logger.info("Area selection cancelled")
            return
        }

        // Find the corresponding SCDisplay for the selected screen
        do {
            let content = try await SCShareableContent.current
            let screenNumber = result.screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID

            guard let display = content.displays.first(where: { $0.displayID == screenNumber }) else {
                logger.error("Could not find SCDisplay for selected screen")
                return
            }

            // Create a content filter for the full display
            let filter = SCContentFilter(display: display, excludingWindows: [])

            // Convert screen rect (NSScreen coordinates, bottom-left origin) to
            // sourceRect (display coordinates, top-left origin)
            let displayHeight = CGFloat(display.height)
            let screenOrigin = result.screen.frame.origin

            let localX = result.screenRect.origin.x - screenOrigin.x
            let localY = result.screenRect.origin.y - screenOrigin.y

            // Flip Y: NSScreen has origin at bottom-left, sourceRect uses top-left
            let flippedY = displayHeight - localY - result.screenRect.height

            // Snap dimensions to even pixel counts for codec compatibility
            let scale = result.screen.backingScaleFactor
            let pixelWidth = result.screenRect.width * scale
            let pixelHeight = result.screenRect.height * scale
            let evenPixelWidth = ceil(pixelWidth / 2) * 2
            let evenPixelHeight = ceil(pixelHeight / 2) * 2

            let sourceRect = CGRect(
                x: localX,
                y: flippedY,
                width: evenPixelWidth / scale,
                height: evenPixelHeight / scale
            )

            // Clear any existing picker selection (mutually exclusive)
            captureEngine.clearSelection()

            // Store the area selection and set the filter on the capture engine
            selectedSourceRect = sourceRect
            selectedContentFilter = filter
            try await captureEngine.updateFilter(filter)

            logger.info("Area selected: sourceRect=\(sourceRect.debugDescription), display=\(display.displayID)")

            // Update preview with the display filter and source rect
            await previewService.setContentFilter(filter, sourceRect: sourceRect)

        } catch {
            logger.error("Failed to get shareable content for area selection: \(error.localizedDescription)")
        }
    }

    /// Starts a new recording session
    func startRecording() async {
        guard canStartRecording else {
            logger.warning("Cannot start recording: no content selected or already recording")
            return
        }

        do {
            state = .recording
            lastError = nil

            logger.info("Starting recording sequence...")

            // Stop any active live preview before starting recording
            logger.info("Stopping any active live preview...")
            await previewService.stopPreview()
            logger.info("Live preview stopped")

            // Determine video size from filter
            if let filter = selectedContentFilter {
                videoSize = await getContentSize(from: filter)
            }
            logger.info("Video size: \(self.videoSize.width)x\(self.videoSize.height)")

            // Setup asset writer
            let outputURL = settings.generateOutputURL()
            try assetWriter.setup(url: outputURL, settings: settings, videoSize: videoSize)
            try assetWriter.startWriting()
            logger.info("AssetWriter ready")

            // Start capture with the calculated video size
            logger.info("Starting capture engine...")
            try await captureEngine.startCapture(with: settings, videoSize: videoSize, sourceRect: selectedSourceRect)

            // Start timer
            startTimer()

            logger.info("Recording started")

        } catch {
            state = .idle
            lastError = error
            logger.error("Failed to start recording: \(error.localizedDescription)")
        }
    }

    /// Stops the current recording session
    func stopRecording() async {
        guard isRecording else { return }

        state = .stopping
        stopTimer()

        do {
            // Stop capture first
            try await captureEngine.stopCapture()

            // Finalize file
            let outputURL = try await assetWriter.finishWriting()

            state = .idle
            recordingDuration = 0

            logger.info("Recording stopped and saved to: \(outputURL.lastPathComponent)")

            // Brief delay to ensure screen sharing mode has fully stopped before sending notification
            try? await Task.sleep(for: .milliseconds(100))

            // Send notification
            notificationService.sendRecordingSavedNotification(fileURL: outputURL)

        } catch {
            state = .idle
            lastError = error
            assetWriter.cancel()
            notificationService.sendRecordingFailedNotification(error: error)
            logger.error("Failed to stop recording: \(error.localizedDescription)")
        }
    }

    /// Clears the current content selection
    func clearSelection() {
        captureEngine.clearSelection()
    }

    /// Starts the live preview stream (call when menu bar window opens)
    func startPreview() async {
        guard !isRecording else { return }
        await previewService.startPreview()
    }

    /// Stops the live preview stream (call when menu bar window closes)
    func stopPreview() async {
        await previewService.stopPreview()
    }

    // MARK: - Timer Management

    private func startTimer() {
        recordingStartTime = Date()
        recordingDuration = 0

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let startTime = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
    }

    // MARK: - Helper Methods

    private func getContentSize(from filter: SCContentFilter) async -> CGSize {
        // If area selection is active, use the source rect dimensions.
        // The sourceRect is already snapped to even pixel counts in presentAreaSelection().
        if let sourceRect = selectedSourceRect {
            let scale = CGFloat(filter.pointPixelScale)
            return CGSize(width: sourceRect.width * scale, height: sourceRect.height * scale)
        }

        // Get the content rect from the filter
        let rect = filter.contentRect
        let scale = CGFloat(filter.pointPixelScale)

        if rect.width > 0 && rect.height > 0 {
            return CGSize(
                width: rect.width * scale,
                height: rect.height * scale
            )
        }

        // Fallback to main screen size
        if let screen = NSScreen.main {
            return CGSize(
                width: screen.frame.width * screen.backingScaleFactor,
                height: screen.frame.height * screen.backingScaleFactor
            )
        }

        return CGSize(width: 1920, height: 1080)
    }
}

// MARK: - CaptureEngineDelegate

extension RecorderViewModel: CaptureEngineDelegate {

    func captureEngine(_ engine: CaptureEngine, didUpdateFilter filter: SCContentFilter) {
        // Clear any area selection (picker and area selections are mutually exclusive)
        selectedSourceRect = nil

        selectedContentFilter = filter
        logger.info("Content filter updated")

        // Capture a static thumbnail for the preview
        Task {
            await previewService.setContentFilter(filter)
        }
    }

    func captureEngine(_ engine: CaptureEngine, didStopWithError error: Error?) {
        // Check if user clicked "Stop Sharing" in the menu bar
        let isUserStopped = (error as? SCStreamError)?.code == .userStopped

        if let error, !isUserStopped {
            lastError = error
            logger.error("Capture stopped with error: \(error.localizedDescription)")
        }

        // Clean up if we were recording
        if isRecording {
            if isUserStopped {
                // User clicked "Stop Sharing" - gracefully save the recording
                logger.info("User stopped sharing via system UI, saving recording...")
                Task {
                    await stopRecording()
                }
            } else {
                // Stream error during recording - try to save what we have
                logger.warning("Stream stopped unexpectedly, attempting to save recording...")
                Task {
                    await stopRecording()
                }
            }
        }
    }

    func captureEngineDidCancelPicker(_ engine: CaptureEngine) {
        logger.info("Picker was cancelled, clearing selection and preview")

        // Clear the selected content filter
        selectedContentFilter = nil

        // Stop and clear the preview
        Task {
            await previewService.cancelCapture()
            previewService.clearPreview()
        }
    }
}

// MARK: - PreviewServiceDelegate

extension RecorderViewModel: PreviewServiceDelegate {

    func previewServiceDidStopByUser(_ service: PreviewService) {
        logger.info("User stopped sharing via system UI, clearing selection")

        // Clear the selection
        selectedContentFilter = nil

        // Clear the content filter in capture engine and deactivate picker
        captureEngine.clearSelection()
        captureEngine.deactivatePicker()
    }
}
