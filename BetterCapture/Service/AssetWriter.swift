//
//  AssetWriter.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 29.01.26.
//

import Foundation
import AVFoundation
import ScreenCaptureKit
import OSLog
import os

/// Service responsible for writing captured media to disk using AVAssetWriter
final class AssetWriter: CaptureEngineSampleBufferDelegate, @unchecked Sendable {

    // MARK: - Properties

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audioInput: AVAssetWriterInput?
    private var microphoneInput: AVAssetWriterInput?

    private(set) var isWriting = false
    private(set) var outputURL: URL?

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture", category: "AssetWriter")

    // Track if we've received the first sample
    private var hasStartedSession = false
    private var sessionStartTime: CMTime = .zero

    /// Last appended video presentation time — used to enforce monotonically
    /// increasing timestamps and protect the writer from timing glitches that
    /// occur when Presenter Overlay composites the camera into the stream.
    private var lastVideoPresentationTime: CMTime = .invalid

    // Lock for thread-safe access to writer state
    private let lock = OSAllocatedUnfairLock()

    // MARK: - Setup

    /// Prepares the asset writer for recording
    /// - Parameters:
    ///   - url: The output file URL
    ///   - settings: The settings store containing encoding configuration
    ///   - videoSize: The dimensions of the video
    func setup(url: URL, settings: SettingsStore, videoSize: CGSize) throws {
        // Ensure output directory exists
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Remove existing file if present
        if FileManager.default.fileExists(atPath: url.path()) {
            try FileManager.default.removeItem(at: url)
        }

        // Create asset writer
        let fileType = settings.containerFormat == .mov ? AVFileType.mov : AVFileType.mp4
        assetWriter = try AVAssetWriter(outputURL: url, fileType: fileType)

        guard let assetWriter else {
            throw AssetWriterError.failedToCreateWriter
        }

        // Configure video input
        let videoSettings = createVideoSettings(from: settings, size: videoSize)
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        if let videoInput, assetWriter.canAdd(videoInput) {
            assetWriter.add(videoInput)

            // Create pixel buffer adaptor for appending raw pixel buffers from ScreenCaptureKit
            // Use HDR 10-bit format when HDR is enabled with a compatible codec
            let pixelFormat: OSType = (settings.captureHDR && settings.videoCodec.supportsHDR)
                ? kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
                : kCVPixelFormatType_32BGRA

            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
                kCVPixelBufferWidthKey as String: Int(videoSize.width),
                kCVPixelBufferHeightKey as String: Int(videoSize.height)
            ]
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput,
                sourcePixelBufferAttributes: sourcePixelBufferAttributes
            )
        }

        // Configure audio input for system audio
        if settings.captureSystemAudio {
            let audioSettings = createAudioSettings(from: settings)
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput?.expectsMediaDataInRealTime = true

            if let audioInput, assetWriter.canAdd(audioInput) {
                assetWriter.add(audioInput)
            }
        }

        // Configure microphone input as separate track
        if settings.captureMicrophone {
            let micSettings = createAudioSettings(from: settings)
            microphoneInput = AVAssetWriterInput(mediaType: .audio, outputSettings: micSettings)
            microphoneInput?.expectsMediaDataInRealTime = true

            if let microphoneInput, assetWriter.canAdd(microphoneInput) {
                assetWriter.add(microphoneInput)
            }
        }

        outputURL = url
        hasStartedSession = false
        sessionStartTime = .zero
        lastVideoPresentationTime = .invalid
        frameCount = 0

        logger.info("AssetWriter configured for output: \(url.lastPathComponent)")
    }

    // MARK: - Writing

    /// Starts the writing session
    func startWriting() throws {
        guard let assetWriter, assetWriter.status == .unknown else {
            throw AssetWriterError.writerNotReady
        }

        guard assetWriter.startWriting() else {
            throw AssetWriterError.failedToStartWriting(assetWriter.error)
        }

        isWriting = true
        logger.info("AssetWriter started writing")
    }

    // Track frame counts for debugging
    private var frameCount = 0

    /// Appends a video sample buffer - called synchronously from capture queue
    func appendVideoSample(_ sampleBuffer: CMSampleBuffer) {
        // Check frame status first - only process complete frames
        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[String: Any]],
              let attachments = attachmentsArray.first,
              let statusRawValue = attachments[SCStreamFrameInfo.status.rawValue] as? Int,
              let status = SCFrameStatus(rawValue: statusRawValue) else {
            logger.warning("Could not extract frame status from sample buffer")
            return
        }

        guard status == .complete else {
            // Frame is not complete (idle, blank, etc.) - skip silently
            return
        }

        lock.withLockUnchecked {
            guard let assetWriter,
                  assetWriter.status == .writing,
                  let videoInput,
                  videoInput.isReadyForMoreMediaData,
                  let adaptor = pixelBufferAdaptor else {
                return
            }

            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            // Start session on first sample
            if !hasStartedSession {
                assetWriter.startSession(atSourceTime: presentationTime)
                sessionStartTime = presentationTime
                hasStartedSession = true
                logger.info("Session started at time: \(presentationTime.seconds)")
            } else {
                // Guard against non-monotonic timestamps. Presenter Overlay can
                // cause timing glitches when compositing the camera into the
                // stream; a single bad timestamp permanently fails the writer.
                if lastVideoPresentationTime.isValid && presentationTime <= lastVideoPresentationTime {
                    return
                }
            }

            // Extract pixel buffer from sample buffer
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                logger.warning("No image buffer in complete video frame")
                return
            }

            // Append using the pixel buffer adaptor
            if adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
                lastVideoPresentationTime = presentationTime
                frameCount += 1
                if frameCount == 1 {
                    logger.info("First video frame appended successfully")
                }
            } else {
                if let error = assetWriter.error {
                    logger.error("Failed to append video pixel buffer: \(error.localizedDescription)")
                } else {
                    logger.error("Failed to append video pixel buffer - no error available")
                }
            }
        }
    }

    /// Appends a system audio sample buffer - called synchronously from capture queue
    func appendAudioSample(_ sampleBuffer: CMSampleBuffer) {
        lock.withLockUnchecked {
            guard let assetWriter,
                  assetWriter.status == .writing,
                  let audioInput,
                  audioInput.isReadyForMoreMediaData else {
                return
            }

            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            // Start session on first sample if video hasn't started it yet
            if !hasStartedSession {
                assetWriter.startSession(atSourceTime: presentationTime)
                sessionStartTime = presentationTime
                hasStartedSession = true
                logger.info("Session started at time: \(presentationTime.seconds)")
            }

            if !audioInput.append(sampleBuffer) {
                logger.error("Failed to append audio sample buffer")
            }
        }
    }

    /// Appends a microphone audio sample buffer
    func appendMicrophoneSample(_ sampleBuffer: CMSampleBuffer) {
        lock.withLockUnchecked {
            guard let assetWriter,
                  assetWriter.status == .writing,
                  let microphoneInput,
                  microphoneInput.isReadyForMoreMediaData else {
                return
            }

            if !microphoneInput.append(sampleBuffer) {
                logger.error("Failed to append microphone sample buffer")
            }
        }
    }

    // MARK: - Finalization

    /// Finishes writing and finalizes the output file
    func finishWriting() async throws -> URL {
        // First critical section: validate state and mark inputs as finished
        let (writerToFinish, url): (AVAssetWriter, URL)

        do {
            (writerToFinish, url) = try lock.withLockUnchecked {
                guard let assetWriter, isWriting else {
                    throw AssetWriterError.writerNotReady
                }

                guard let url = outputURL else {
                    throw AssetWriterError.noOutputURL
                }

                logger.info("Finishing writing - status: \(assetWriter.status.rawValue), session started: \(self.hasStartedSession), frames written: \(self.frameCount)")

                // Check if we actually started a session (received at least one frame)
                guard hasStartedSession else {
                    logger.error("No frames were written - session was never started")
                    throw AssetWriterError.noFramesWritten
                }

                // Mark inputs as finished
                videoInput?.markAsFinished()
                audioInput?.markAsFinished()
                microphoneInput?.markAsFinished()

                return (assetWriter, url)
            }
        } catch AssetWriterError.noFramesWritten {
            // Cancel needs to be called outside the lock since it acquires its own lock
            cancel()
            throw AssetWriterError.noFramesWritten
        }

        // Finish writing (outside lock since it's async)
        await writerToFinish.finishWriting()

        // Second critical section: check final status and cleanup
        return try lock.withLockUnchecked {
            guard let assetWriter else {
                throw AssetWriterError.writerNotReady
            }

            if assetWriter.status == .failed {
                let error = assetWriter.error
                logger.error("AssetWriter failed: \(error?.localizedDescription ?? "unknown error")")
                throw AssetWriterError.writingFailed(error)
            }

            isWriting = false
            hasStartedSession = false
            lastVideoPresentationTime = .invalid

            logger.info("AssetWriter finished writing \(self.frameCount) frames to: \(url.lastPathComponent)")
            frameCount = 0

            // Clean up
            self.assetWriter = nil
            self.videoInput = nil
            self.pixelBufferAdaptor = nil
            self.audioInput = nil
            self.microphoneInput = nil

            return url
        }
    }

    /// Cancels the current writing session
    func cancel() {
        lock.withLockUnchecked {
            assetWriter?.cancelWriting()
            isWriting = false
            hasStartedSession = false
            lastVideoPresentationTime = .invalid
            frameCount = 0

            // Clean up temp file if it exists
            if let url = outputURL {
                try? FileManager.default.removeItem(at: url)
            }

            assetWriter = nil
            videoInput = nil
            pixelBufferAdaptor = nil
            audioInput = nil
            microphoneInput = nil
            outputURL = nil

            logger.info("AssetWriter cancelled")
        }
    }

    // MARK: - Settings Helpers

    private func createVideoSettings(from settings: SettingsStore, size: CGSize) -> [String: Any] {
        var videoSettings: [String: Any] = [
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ]

        switch settings.videoCodec {
        case .h264:
            videoSettings[AVVideoCodecKey] = AVVideoCodecType.h264

        case .hevc:
            if settings.captureAlphaChannel {
                videoSettings[AVVideoCodecKey] = AVVideoCodecType.hevcWithAlpha
            } else {
                videoSettings[AVVideoCodecKey] = AVVideoCodecType.hevc
            }

        case .proRes422:
            videoSettings[AVVideoCodecKey] = AVVideoCodecType.proRes422

        case .proRes4444:
            videoSettings[AVVideoCodecKey] = AVVideoCodecType.proRes4444
        }

        // Add compression properties for H.264 and HEVC to control bitrate.
        // ProRes codecs use fixed-quality encoding and don't need these.
        if let bpp = settings.videoQuality.bitsPerPixel(for: settings.videoCodec) {
            let frameRate = settings.frameRate == .native ? 60.0 : Double(settings.frameRate.rawValue)
            let bitrate = Int(size.width * size.height * bpp * frameRate)

            videoSettings[AVVideoCompressionPropertiesKey] = [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoExpectedSourceFrameRateKey: frameRate,
                AVVideoMaxKeyFrameIntervalKey: Int(frameRate * 2)
            ]

            logger.info("Video compression: \(bitrate / 1_000_000) Mbps at \(Int(frameRate)) fps (\(settings.videoQuality.rawValue) quality)")
        }

        // Add HDR color space settings for ProRes codecs with HDR enabled
        if settings.captureHDR && settings.videoCodec.supportsHDR {
            videoSettings[AVVideoColorPropertiesKey] = [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020
            ]
        }

        return videoSettings
    }

    private func createAudioSettings(from settings: SettingsStore) -> [String: Any] {
        switch settings.audioCodec {
        case .aac:
            return [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 256000
            ]

        case .pcm:
            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
        }
    }
}

// MARK: - CaptureEngineSampleBufferDelegate

extension AssetWriter {

    func captureEngine(_ engine: CaptureEngine, didOutputVideoSampleBuffer sampleBuffer: CMSampleBuffer) {
        appendVideoSample(sampleBuffer)
    }

    func captureEngine(_ engine: CaptureEngine, didOutputAudioSampleBuffer sampleBuffer: CMSampleBuffer) {
        appendAudioSample(sampleBuffer)
    }

    func captureEngine(_ engine: CaptureEngine, didOutputMicrophoneSampleBuffer sampleBuffer: CMSampleBuffer) {
        appendMicrophoneSample(sampleBuffer)
    }
}

// MARK: - Errors

enum AssetWriterError: LocalizedError {
    case failedToCreateWriter
    case writerNotReady
    case failedToStartWriting(Error?)
    case writingFailed(Error?)
    case noOutputURL
    case noFramesWritten

    var errorDescription: String? {
        switch self {
        case .failedToCreateWriter:
            return "Failed to create the asset writer."
        case .writerNotReady:
            return "The asset writer is not ready for writing."
        case .failedToStartWriting(let error):
            return "Failed to start writing: \(error?.localizedDescription ?? "Unknown error")"
        case .writingFailed(let error):
            return "Writing failed: \(error?.localizedDescription ?? "Unknown error")"
        case .noOutputURL:
            return "No output URL was configured."
        case .noFramesWritten:
            return "No video frames were captured. Check screen recording permissions."
        }
    }
}
