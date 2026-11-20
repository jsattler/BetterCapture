//
//  RecordingSession.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 20.11.26.
//

import AppKit
import OSLog
import ScreenCaptureKit

/// A recording started from the command line.
///
/// Each session has its own capture stream and writer, so any number of them can run at
/// once, independently of the recording controlled from the menu bar. Presenter Overlay isn't
/// supported, since sessions would compete for the camera.
@MainActor
@Observable
final class RecordingSession {

    typealias State = RecordingInfo.State

    /// A short random ID, such as `3f9c1a2e`
    let id: String
    let name: String?
    /// What is recorded, in words, see ``RecordingInfo/target``
    let target: String

    private(set) var state: State = .recording
    private(set) var startedAt = Date.now
    private(set) var endedAt: Date?
    private(set) var outputURL: URL?
    private(set) var error: Error?

    var isActive: Bool {
        state == .recording || state == .paused
    }

    var hasEnded: Bool {
        state == .finished || state == .failed
    }

    private let settings: SettingsStore
    private let notificationService: NotificationService
    private let captureEngine = CaptureEngine(usesPicker: false)
    private let assetWriter = AssetWriter()
    private let selectionBorderFrame = SelectionBorderFrame()
    private var clock = RecordingClock()
    private var durationTask: Task<Void, Never>?

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture", category: "RecordingSession")

    init(id: String, name: String?, target: String, settings: SettingsStore, notificationService: NotificationService) {
        self.id = id
        self.name = name
        self.target = target
        self.settings = settings
        self.notificationService = notificationService

        captureEngine.delegate = self
        captureEngine.sampleBufferDelegate = assetWriter
    }

    // MARK: - Recording

    /// Starts recording, throwing if the recording couldn't be started
    /// - Parameters:
    ///   - filter: The content to capture
    ///   - sourceRect: The area to capture within a display filter (display points, top-left origin)
    ///   - screen: The screen the area is on, used to show its border while recording
    ///   - durationSeconds: Stops the recording automatically after this many seconds
    func start(filter: SCContentFilter, sourceRect: CGRect?, screen: NSScreen?, durationSeconds: Double?) async throws {
        let videoSize = CaptureSizeCalculator.videoSize(
            for: filter,
            sourceRect: sourceRect,
            useNativeResolution: settings.captureNativeResolution
        )

        _ = settings.startAccessingOutputDirectory()

        do {
            // Nothing is awaited between picking the URL and creating the file, so another
            // session starting at the same time can't pick the same URL
            let url = settings.generateOutputURL()
            try assetWriter.setup(url: url, settings: settings, videoSize: videoSize)
            try assetWriter.startWriting()
            outputURL = url

            try await captureEngine.updateFilter(filter)
            try await captureEngine.startCapture(with: settings, videoSize: videoSize, sourceRect: sourceRect)
        } catch {
            assetWriter.cancel()
            settings.stopAccessingOutputDirectory()
            logger.error("Failed to start recording \(self.id): \(error.localizedDescription)")
            throw error
        }

        startedAt = .now
        clock = RecordingClock(startedAt: startedAt)

        if let sourceRect, let screen {
            selectionBorderFrame.show(screenRect: Self.screenRect(for: sourceRect, on: screen))
        }

        if let durationSeconds {
            durationTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(durationSeconds))
                guard !Task.isCancelled else { return }
                await self?.stop()
            }
        }

        logger.info("Recording \(self.id) started")
    }

    func stop(copyToClipboard: Bool = false) async {
        guard isActive else { return }

        state = .stopping
        endedAt = .now
        durationTask?.cancel()
        durationTask = nil
        selectionBorderFrame.dismiss()

        defer { settings.stopAccessingOutputDirectory() }

        do {
            try await captureEngine.stopCapture()
            let (outputURL, videoFrameCount) = try await assetWriter.finishWriting()
            state = .finished

            logger.info("Recording \(self.id) saved to: \(outputURL.lastPathComponent)")

            // The file is kept either way, but the user has to be told about a missing video track
            if videoFrameCount == 0 {
                notificationService.sendRecordingMissingVideoNotification(fileURL: outputURL)
            } else {
                notificationService.sendRecordingSavedNotification(fileURL: outputURL)
            }

            if copyToClipboard {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([outputURL as NSURL])
            }
        } catch {
            state = .failed
            self.error = error
            assetWriter.cancel()
            notificationService.sendRecordingFailedNotification(error: error)
            logger.error("Failed to stop recording \(self.id): \(error.localizedDescription)")
        }
    }

    func pause() {
        guard state == .recording else { return }
        clock.pause()
        assetWriter.pause()
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        clock.resume()
        assetWriter.resume()
        state = .recording
    }

    /// Returns once the recording has ended, however it ends
    func waitUntilEnded() async {
        while !hasEnded {
            await withCheckedContinuation { continuation in
                withObservationTracking {
                    _ = state
                } onChange: {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Info

    var info: RecordingInfo {
        RecordingInfo(
            id: id,
            name: name,
            state: state,
            target: target,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: clock.elapsed(at: endedAt ?? .now),
            outputPath: outputURL?.path(percentEncoded: false) ?? "",
            error: error?.localizedDescription
        )
    }

    /// Flips an area from the display's top-left origin to the bottom-left origin of screen coordinates
    private static func screenRect(for sourceRect: CGRect, on screen: NSScreen) -> CGRect {
        CGRect(
            x: screen.frame.minX + sourceRect.minX,
            y: screen.frame.maxY - sourceRect.maxY,
            width: sourceRect.width,
            height: sourceRect.height
        )
    }
}

// MARK: - CaptureEngineDelegate

extension RecordingSession: CaptureEngineDelegate {

    func captureEngine(_ engine: CaptureEngine, didStopWithError error: Error?) {
        // The user clicked "Stop Sharing", or the stream failed. Either way, save what was recorded.
        if let error, (error as? SCStreamError)?.code != .userStopped {
            logger.error("Recording \(self.id) stopped unexpectedly: \(error.localizedDescription)")
        }
        Task {
            await stop()
        }
    }

    func captureEngine(_ engine: CaptureEngine, systemAudioDidFailWith error: Error?) {
        // The video recording keeps running; only system audio is missing from the output
        notificationService.sendSystemAudioFailedNotification(error: error)
    }

    // Content is never chosen with the picker, and Presenter Overlay isn't supported
    func captureEngine(_ engine: CaptureEngine, didUpdateFilter filter: SCContentFilter) {}
    func captureEngineDidCancelPicker(_ engine: CaptureEngine) {}
    func captureEngine(_ engine: CaptureEngine, presenterOverlayDidChange isActive: Bool) {}
}
