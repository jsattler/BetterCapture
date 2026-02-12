//
//  PreviewService.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 02.02.26.
//

import ScreenCaptureKit
import AppKit
import OSLog

/// Delegate protocol for preview service events
@MainActor
protocol PreviewServiceDelegate: AnyObject {
    func previewServiceDidStopByUser(_ service: PreviewService)
}

/// Service for generating preview snapshots of selected capture content
@MainActor
@Observable
final class PreviewService: NSObject {

    // MARK: - Properties

    weak var delegate: PreviewServiceDelegate?

    private(set) var previewImage: NSImage?
    private(set) var isCapturing = false

    private var stream: SCStream?
    private var currentFilter: SCContentFilter?
    private var currentSourceRect: CGRect?
    private let previewQueue = DispatchQueue(label: "com.bettercapture.previewQueue", qos: .userInteractive)

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture",
        category: "PreviewService"
    )

    // Preview configuration constants - optimized for live preview
    private let previewWidth = 320
    private let previewHeight = 200

    // MARK: - Public Methods

    /// Updates the content filter and captures a static thumbnail
    /// - Parameters:
    ///   - filter: The content filter to use
    ///   - sourceRect: Optional rectangle for area selection (display points, top-left origin)
    func setContentFilter(_ filter: SCContentFilter, sourceRect: CGRect? = nil) async {
        currentFilter = filter
        currentSourceRect = sourceRect
        await captureStaticThumbnail(for: filter, sourceRect: sourceRect)
    }

    /// Captures a single static frame as a thumbnail (no continuous streaming)
    /// - Parameters:
    ///   - filter: The content filter to capture
    ///   - sourceRect: Optional rectangle for area selection (display points, top-left origin)
    private func captureStaticThumbnail(for filter: SCContentFilter, sourceRect: CGRect? = nil) async {
        let config = SCStreamConfiguration()
        config.width = previewWidth
        config.height = previewHeight
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true

        if let sourceRect {
            config.sourceRect = sourceRect
        }

        do {
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
            previewImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            logger.info("Static thumbnail captured")
        } catch {
            logger.error("Failed to capture static thumbnail: \(error.localizedDescription)")
        }
    }

    /// Starts the preview stream if a content filter is set
    func startPreview() async {
        guard let filter = currentFilter else {
            logger.info("No content filter set, skipping preview start")
            return
        }

        // If already streaming, just update the filter
        if let stream, isCapturing {
            do {
                try await stream.updateContentFilter(filter)
                logger.info("Updated preview stream filter")
            } catch {
                logger.error("Failed to update preview filter: \(error.localizedDescription)")
                await stopStream()
                await startStream(with: filter)
            }
            return
        }

        // Otherwise start a new stream
        await startStream(with: filter)
    }

    /// Stops the preview stream
    func stopPreview() async {
        await stopStream()
    }

    /// Starts or updates the preview stream for the given content filter
    /// - Parameter filter: The content filter to capture
    func captureSnapshot(for filter: SCContentFilter) async {
        currentFilter = filter

        // If already streaming, update the filter
        if let stream, isCapturing {
            do {
                try await stream.updateContentFilter(filter)
                logger.info("Updated preview stream filter")
            } catch {
                logger.error("Failed to update preview filter: \(error.localizedDescription)")
                await stopStream()
                await startStream(with: filter)
            }
            return
        }

        // Otherwise start a new stream
        await startStream(with: filter)
    }

    /// Starts the preview stream
    private func startStream(with filter: SCContentFilter) async {
        guard !isCapturing else { return }

        isCapturing = true

        do {
            let config = createPreviewConfiguration()
            stream = SCStream(filter: filter, configuration: config, delegate: self)

            guard let stream else {
                logger.error("Failed to create preview stream")
                isCapturing = false
                return
            }

            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: previewQueue)
            try await stream.startCapture()

            logger.info("Preview stream started")

        } catch let error as NSError {
            // Handle TCC permission errors gracefully
            if error.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain" && error.code == -3801 {
                logger.warning("Screen capture permission not granted")
            } else {
                logger.error("Failed to start preview: \(error.localizedDescription)")
            }
            await stopStream()
        }
    }

    /// Clears the current preview image
    func clearPreview() {
        previewImage = nil
    }

    /// Stops the preview stream
    func cancelCapture() async {
        await stopStream()
    }

    // MARK: - Private Methods

    private func stopStream() async {
        if let stream {
            do {
                try await stream.stopCapture()
                logger.info("Preview stream stopped")
            } catch {
                logger.error("Failed to stop preview stream: \(error.localizedDescription)")
            }
            self.stream = nil
        }

        // Always ensure isCapturing is false
        isCapturing = false
    }

    private func createPreviewConfiguration() -> SCStreamConfiguration {
        let config = SCStreamConfiguration()

        // Moderate resolution for live preview
        config.width = previewWidth
        config.height = previewHeight

        // Lower frame rate for preview (5 FPS is sufficient)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 5)

        // BGRA pixel format for display
        config.pixelFormat = kCVPixelFormatType_32BGRA

        // No audio for preview
        config.capturesAudio = false

        // Show cursor in preview
        config.showsCursor = true

        // Apply source rect for area selection
        if let sourceRect = currentSourceRect {
            config.sourceRect = sourceRect
        }

        return config
    }

    /// Converts a CMSampleBuffer to an NSImage
    private nonisolated func createImage(from sampleBuffer: CMSampleBuffer) -> NSImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        let size = NSSize(width: cgImage.width, height: cgImage.height)
        return NSImage(cgImage: cgImage, size: size)
    }
}

// MARK: - SCStreamDelegate

extension PreviewService: SCStreamDelegate {

    nonisolated func stream(_ stream: SCStream, didStopWithError error: any Error) {
        Task { @MainActor in
            self.stream = nil
            self.isCapturing = false

            let nsError = error as NSError

            // Check if the user clicked "Stop Sharing" in the system UI
            // Error code -3808 or localized description contains "user stopped"
            let userStoppedSharing = nsError.code == -3808 ||
                                    error.localizedDescription.localizedStandardContains("user stopped")

            if userStoppedSharing {
                logger.info("User clicked 'Stop Sharing', clearing preview and notifying delegate")

                // Clear the preview image
                self.previewImage = nil

                // Notify delegate to clear selection
                self.delegate?.previewServiceDidStopByUser(self)

            } else if nsError.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain" && nsError.code == -3801 {
                logger.warning("Preview stream stopped: permission not granted")
            } else {
                logger.error("Preview stream stopped with error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - SCStreamOutput

extension PreviewService: SCStreamOutput {

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid else { return }

        // Check frame status - only process complete frames
        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[String: Any]],
              let attachments = attachmentsArray.first,
              let statusRawValue = attachments[SCStreamFrameInfo.status.rawValue] as? Int,
              let status = SCFrameStatus(rawValue: statusRawValue),
              status == .complete else {
            return
        }

        // Convert to NSImage
        guard let image = createImage(from: sampleBuffer) else { return }

        Task { @MainActor in
            // Continuously update the preview image with each new frame
            self.previewImage = image
        }
    }
}
