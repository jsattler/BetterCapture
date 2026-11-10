//
//  AssetWriter.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 29.01.26.
//

import AVFoundation
import CoreVideo
import Foundation
import OSLog
import ScreenCaptureKit
import VideoToolbox
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

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture", category: "AssetWriter")

    // Track if we've received the first sample
    private var hasStartedSession = false

    /// Presentation timestamp of the first sample received on any track.
    ///
    /// Every track is rebased against this anchor so the file starts at zero
    /// regardless of which track ScreenCaptureKit delivers first.
    private var sessionAnchor: CMTime = .invalid

    /// The constant frame rate the video track is written at.
    ///
    /// ScreenCaptureKit's `minimumFrameInterval` is a floor rather than a
    /// cadence, so raw capture timestamps jitter and stall. Snapping every frame
    /// to this grid - and duplicating the previous frame across skipped slots -
    /// produces a genuine CFR track, which is what concatenation tools and video
    /// platforms expect.
    private var gridFrameRate: CMTimeScale = 60

    /// Index of the last video frame appended, in `gridFrameRate` units. `-1` before
    /// the first frame.
    private var lastFrameIndex = -1

    /// The most recently appended pixel buffer, reused to fill skipped grid slots.
    private var lastPixelBuffer: CVPixelBuffer?

    /// The newest frame from the capture source and the grid slot it belongs to,
    /// waiting for the writer to accept it.
    private var pendingPixelBuffer: CVPixelBuffer?
    private var pendingIndex = -1

    /// Set when the recording is stopping, so the drain loop closes the video input
    /// once it has written everything queued.
    private var isFinishingVideo = false
    private var videoInputFinished = false
    private var videoDrained: CheckedContinuation<Void, Never>?

    private var hasLoggedFirstFrame = false

    /// Serial queue the writer pulls video frames on when it is ready for more data.
    private let videoDrainQueue = DispatchQueue(
        label: "com.bettercapture.assetWriter.videoDrain", qos: .userInitiated)

    /// Whether the head of each audio track has already been padded with silence.
    private var hasPaddedAudio = false
    private var hasPaddedMicrophone = false

    private var pauseStartedAt: CMTime?
    private var resumedAt: CMTime = .invalid
    private var totalPausedDuration: CMTime = .zero
    private var isPaused = false

    /// Upper bound on how many frames a single gap may be filled with, as a
    /// multiple of `gridFrameRate`. A capture that stalls for longer than this is
    /// left with a hole rather than blocking the capture queue.
    private static let maximumFillSeconds = 10

    /// The active HDR preset for this recording session, used to select the
    /// correct color properties for the output container and per-frame tagging.
    private var activeHDRPreset: HDRPreset = .sdr

    /// Whether per-frame `CVBufferSetAttachment` color tagging is needed.
    /// True only for ProRes HDR, where `AVVideoColorPropertiesKey` must be omitted.
    private var tagBuffersWithHDRColorimetry = false

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

        // Snap video to a constant frame rate grid. `.native` reports 60, which is
        // also the interval CaptureEngine configures for it.
        gridFrameRate = CMTimeScale(settings.frameRate.effectiveFrameRate)

        // Configure video input
        let videoSettings = AssetWriterSettings.video(from: settings, size: videoSize)
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true
        // 600 is evenly divisible by every supported frame rate, so grid times are
        // representable exactly and no rounding is introduced by the writer.
        videoInput?.mediaTimeScale = 600

        if let videoInput, assetWriter.canAdd(videoInput) {
            assetWriter.add(videoInput)

            // Create pixel buffer adaptor for appending raw pixel buffers from ScreenCaptureKit.
            // Must match the pixel format configured on SCStreamConfiguration in CaptureEngine.
            let pixelFormat: OSType =
                (settings.captureHDR && settings.videoCodec.supportsHDR)
                ? settings.videoCodec.hdrPixelFormat
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
            let audioSettings = AssetWriterSettings.audio(from: settings)
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput?.expectsMediaDataInRealTime = true

            if let audioInput, assetWriter.canAdd(audioInput) {
                assetWriter.add(audioInput)
            }
        }

        // Configure microphone input as separate track
        if settings.captureMicrophone {
            let micSettings = AssetWriterSettings.audio(from: settings)
            microphoneInput = AVAssetWriterInput(mediaType: .audio, outputSettings: micSettings)
            microphoneInput?.expectsMediaDataInRealTime = true

            if let microphoneInput, assetWriter.canAdd(microphoneInput) {
                assetWriter.add(microphoneInput)
            }
        }

        activeHDRPreset = settings.hdrPreset
        let isProResHDR = activeHDRPreset != .sdr
            && (settings.videoCodec == .proRes422 || settings.videoCodec == .proRes4444)
        tagBuffersWithHDRColorimetry = isProResHDR

        outputURL = url
        resetTimingState()
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

        // Pull frames whenever the encoder drains. Without this a stall longer than one
        // burst would be left half-filled, because the capture source has nothing to
        // deliver while the screen is static.
        videoInput?.requestMediaDataWhenReady(on: videoDrainQueue) { [weak self] in
            self?.drainVideo()
        }

        isWriting = true
        logger.info("AssetWriter started writing")
    }

    func pause(at time: CMTime = CMClockGetTime(CMClockGetHostTimeClock())) {
        lock.withLockUnchecked {
            guard isWriting, !isPaused, time.isNumeric else { return }
            pauseStartedAt = time
            isPaused = true
        }
    }

    func resume(at time: CMTime = CMClockGetTime(CMClockGetHostTimeClock())) {
        lock.withLockUnchecked {
            guard isWriting, isPaused, time.isNumeric, let pauseStartedAt else { return }
            totalPausedDuration = CMTimeAdd(totalPausedDuration, CMTimeSubtract(time, pauseStartedAt))
            resumedAt = time
            self.pauseStartedAt = nil
            isPaused = false
        }
    }

    // Track frame counts for debugging
    private var frameCount = 0

    /// Appends a video sample buffer - called synchronously from capture queue
    func appendVideoSample(_ sampleBuffer: CMSampleBuffer) {
        // Check frame status first - only process complete frames
        guard
            let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(
                sampleBuffer, createIfNecessary: false) as? [[String: Any]],
            let attachments = attachmentsArray.first,
            let statusRawValue = attachments[SCStreamFrameInfo.status.rawValue] as? Int,
            let status = SCFrameStatus(rawValue: statusRawValue)
        else {
            logger.warning("Could not extract frame status from sample buffer")
            return
        }

        guard status == .complete else {
            // Frame is not complete (idle, blank, etc.) - skip silently
            return
        }

        lock.withLockUnchecked {
            guard let assetWriter, assetWriter.status == .writing else { return }

            guard let presentationTime = adjustedPresentationTime(
                CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            else { return }

            startSessionIfNeeded(at: presentationTime)

            // Snap to the constant frame rate grid. Frames that land on a slot at or
            // before one already claimed are dropped: capture jitter can deliver two
            // frames inside a single slot, and Presenter Overlay can emit an outright
            // non-monotonic timestamp, which permanently fails the writer.
            let index = gridIndex(for: presentationTime)
            guard index > pendingIndex else { return }

            // Extract pixel buffer from sample buffer
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                logger.warning("No image buffer in complete video frame")
                return
            }

            // Log incoming buffer properties on the first frame to aid HDR debugging.
            if !hasLoggedFirstFrame {
                hasLoggedFirstFrame = true
                AssetWriterSettings.logPixelBufferProperties(pixelBuffer)
            }

            // For ProRes HDR, inject BT.2020 / PQ colorimetry directly onto
            // the pixel buffer. AVAssetWriter prohibits AVVideoColorPropertiesKey
            // for the high-bit-depth formats ProRes uses, so we tag each frame
            // to ensure the output file contains correct 'colr' / 'nclx' atoms.
            if tagBuffersWithHDRColorimetry {
                CVBufferSetAttachment(pixelBuffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_2020, .shouldPropagate)
                CVBufferSetAttachment(pixelBuffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ, .shouldPropagate)
                CVBufferSetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_2020, .shouldPropagate)
            }

            // Hand the frame to the drain loop rather than appending here. The writer
            // only accepts a short burst before `isReadyForMoreMediaData` goes false,
            // and appending past that point wedges it.
            pendingPixelBuffer = pixelBuffer
            pendingIndex = index
        }

        drainVideo()
    }

    /// Writes queued frames for as long as the input accepts them.
    ///
    /// Runs both from the capture queue and from `requestMediaDataWhenReady`, so a stall
    /// that outlasts a single burst is finished as soon as the encoder drains. Every slot
    /// between the last frame written and the newest frame is filled with a repeat of the
    /// last frame, which is what keeps the track at a constant frame rate.
    private func drainVideo() {
        lock.withLockUnchecked {
            guard let assetWriter, assetWriter.status == .writing,
                let videoInput, let adaptor = pixelBufferAdaptor, !videoInputFinished
            else {
                return
            }

            capFillIfStalled()

            while videoInput.isReadyForMoreMediaData {
                let slot = lastFrameIndex + 1

                // Fall back to the pending frame while no frame has been written yet, so
                // an audio track that opened the session earlier gets back-filled.
                guard slot <= pendingIndex,
                    let pixelBuffer = slot == pendingIndex
                        ? pendingPixelBuffer : (lastPixelBuffer ?? pendingPixelBuffer)
                else {
                    // Caught up. Close the track once the recording is stopping.
                    if isFinishingVideo {
                        videoInput.markAsFinished()
                        videoInputFinished = true
                        videoDrained?.resume()
                        videoDrained = nil
                    }
                    return
                }

                let gridTime = CMTime(value: CMTimeValue(slot), timescale: gridFrameRate)
                guard adaptor.append(pixelBuffer, withPresentationTime: gridTime) else {
                    logger.error(
                        "Failed to append video pixel buffer: \(assetWriter.error?.localizedDescription ?? "no error available")"
                    )
                    return
                }

                lastFrameIndex = slot
                frameCount += 1
                if slot == pendingIndex {
                    lastPixelBuffer = pixelBuffer
                }
            }
        }
    }

    /// Skips ahead when a stall is longer than the fill cap, so a capture source that
    /// went away for minutes cannot make the drain loop write thousands of frames.
    private func capFillIfStalled() {
        let maximumFill = Int(gridFrameRate) * Self.maximumFillSeconds
        let missing = pendingIndex - lastFrameIndex
        guard missing > maximumFill else { return }

        logger.warning(
            "Capture stalled for \(Double(missing) / Double(self.gridFrameRate))s - filling only \(maximumFill) frames"
        )
        lastFrameIndex = pendingIndex - maximumFill
    }

    /// Appends a system audio sample buffer - called synchronously from capture queue
    func appendAudioSample(_ sampleBuffer: CMSampleBuffer) {
        lock.withLockUnchecked {
            guard let assetWriter,
                assetWriter.status == .writing,
                let audioInput,
                audioInput.isReadyForMoreMediaData
            else {
                return
            }

            guard let presentationTime = adjustedPresentationTime(
                CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            else { return }

            startSessionIfNeeded(at: presentationTime)

            if !hasPaddedAudio {
                hasPaddedAudio = true
                padWithSilence(sampleBuffer, before: presentationTime, into: audioInput, label: "system audio")
            }

            append(sampleBuffer, rebasedInto: audioInput, label: "audio")
        }
    }

    /// Appends a microphone audio sample buffer
    func appendMicrophoneSample(_ sampleBuffer: CMSampleBuffer) {
        lock.withLockUnchecked {
            guard let assetWriter,
                assetWriter.status == .writing,
                let microphoneInput,
                microphoneInput.isReadyForMoreMediaData
            else {
                return
            }

            guard let presentationTime = adjustedPresentationTime(
                CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            else { return }

            startSessionIfNeeded(at: presentationTime)

            if !hasPaddedMicrophone {
                hasPaddedMicrophone = true
                padWithSilence(sampleBuffer, before: presentationTime, into: microphoneInput, label: "microphone")
            }

            append(sampleBuffer, rebasedInto: microphoneInput, label: "microphone")
        }
    }

    // MARK: - Timing

    /// Opens the writing session on the first sample from any track.
    ///
    /// The anchor is shared by video and both audio tracks so they all resolve to a
    /// common origin of zero.
    private func startSessionIfNeeded(at presentationTime: CMTime) {
        guard !hasStartedSession, let assetWriter else { return }

        sessionAnchor = presentationTime
        hasStartedSession = true
        assetWriter.startSession(atSourceTime: .zero)
        logger.info("Session anchored at capture time: \(presentationTime.seconds)")
    }

    /// Converts a capture timestamp into an index on the constant frame rate grid.
    private func gridIndex(for presentationTime: CMTime) -> Int {
        let elapsed = (presentationTime - sessionAnchor).seconds
        guard elapsed.isFinite else { return lastFrameIndex + 1 }
        return max(0, Int((elapsed * Double(gridFrameRate)).rounded()))
    }

    /// Drops samples captured during a pause and shifts later timestamps back over it.
    private func adjustedPresentationTime(_ presentationTime: CMTime) -> CMTime? {
        guard !isPaused, presentationTime.isNumeric else { return nil }
        if resumedAt.isNumeric, CMTimeCompare(presentationTime, resumedAt) < 0 {
            return nil
        }
        return CMTimeSubtract(presentationTime, totalPausedDuration)
    }

    /// Writes silence covering the gap between the session anchor and this track's
    /// first sample, so the track begins at time zero.
    private func padWithSilence(
        _ sampleBuffer: CMSampleBuffer,
        before presentationTime: CMTime,
        into input: AVAssetWriterInput,
        label: String
    ) {
        let offset = presentationTime - sessionAnchor
        guard offset.isNumeric, offset > .zero,
            let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
            let silence = SilentAudioBuffer.make(
                matching: formatDescription, duration: offset, at: .zero)
        else {
            return
        }

        if input.append(silence) {
            logger.info("Padded \(label) with \(offset.seconds * 1000, format: .fixed(precision: 1))ms of silence")
        } else {
            logger.error("Failed to pad \(label) with silence")
        }
    }

    /// Rebases a sample buffer against the session anchor and appends it.
    private func append(
        _ sampleBuffer: CMSampleBuffer, rebasedInto input: AVAssetWriterInput, label: String
    ) {
        guard let rebased = rebase(sampleBuffer) else {
            logger.error("Failed to rebase \(label) sample buffer")
            return
        }

        if !input.append(rebased) {
            logger.error("Failed to append \(label) sample buffer")
        }
    }

    /// Returns a copy of `sampleBuffer` with its timestamps shifted so the session
    /// anchor maps to zero.
    private func rebase(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        guard var timings = try? sampleBuffer.sampleTimingInfos() else { return nil }

        let origin = CMTimeAdd(sessionAnchor, totalPausedDuration)
        for index in timings.indices {
            timings[index].presentationTimeStamp = CMTimeSubtract(
                timings[index].presentationTimeStamp, origin)
            if timings[index].decodeTimeStamp.isNumeric {
                timings[index].decodeTimeStamp = CMTimeSubtract(
                    timings[index].decodeTimeStamp, origin)
            }
        }

        var copy: CMSampleBuffer?
        let status = CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: CMItemCount(timings.count),
            sampleTimingArray: &timings,
            sampleBufferOut: &copy
        )

        guard status == noErr else { return nil }
        return copy
    }

    /// Suspends until the drain loop has written every queued frame and closed the
    /// video input.
    ///
    /// Returns immediately when there is no video input, or when the writer already
    /// stopped accepting data, so a failed or audio-only recording cannot hang here.
    private func waitForVideoDrain() async {
        await withCheckedContinuation { continuation in
            let shouldWait = lock.withLockUnchecked { () -> Bool in
                guard videoInput != nil, !videoInputFinished,
                    assetWriter?.status == .writing
                else {
                    return false
                }

                videoDrained = continuation
                return true
            }

            if !shouldWait {
                continuation.resume()
                return
            }

            // Kick the loop in case the input is already ready and idle
            videoDrainQueue.async { [weak self] in self?.drainVideo() }
        }
    }

    /// Clears all per-recording timing state.
    ///
    /// Any caller still waiting on the drain is released, so cancelling a recording
    /// cannot strand `finishWriting`.
    private func resetTimingState() {
        videoDrained?.resume()
        videoDrained = nil

        hasStartedSession = false
        sessionAnchor = .invalid
        lastFrameIndex = -1
        lastPixelBuffer = nil
        pendingPixelBuffer = nil
        pendingIndex = -1
        isFinishingVideo = false
        videoInputFinished = false
        hasLoggedFirstFrame = false
        hasPaddedAudio = false
        hasPaddedMicrophone = false
        pauseStartedAt = nil
        resumedAt = .invalid
        totalPausedDuration = .zero
        isPaused = false
    }

    // MARK: - Finalization

    /// Finishes writing and finalizes the output file
    /// - Returns: The output URL and the number of video frames written. A count of zero
    ///            means the file holds audio only, which happens when the capture source
    ///            stopped producing frames while audio kept flowing.
    func finishWriting() async throws -> (url: URL, videoFrameCount: Int) {
        // First critical section: validate state and let the drain loop close the video
        let (writerToFinish, url): (AVAssetWriter, URL)

        do {
            (writerToFinish, url) = try lock.withLockUnchecked {
                guard let assetWriter, isWriting else {
                    throw AssetWriterError.writerNotReady
                }

                guard let url = outputURL else {
                    throw AssetWriterError.noOutputURL
                }

                logger.info(
                    "Finishing writing - status: \(assetWriter.status.rawValue), session started: \(self.hasStartedSession), frames written: \(self.frameCount)"
                )

                // Check if we actually started a session (received at least one frame)
                guard hasStartedSession else {
                    logger.error("No frames were written - session was never started")
                    throw AssetWriterError.noFramesWritten
                }

                isFinishingVideo = true
                return (assetWriter, url)
            }
        } catch AssetWriterError.noFramesWritten {
            // Cancel needs to be called outside the lock since it acquires its own lock
            cancel()
            throw AssetWriterError.noFramesWritten
        }

        // Let the drain loop write everything still queued, then close the video input.
        // The encoder only accepts a burst at a time, so this may take several passes.
        await waitForVideoDrain()

        lock.withLockUnchecked {
            // Close the session on the grid boundary after the last frame so the video
            // track's duration is exact instead of inferred from the final sample.
            // Audio-only recordings end at the last audio sample instead.
            if lastFrameIndex >= 0 {
                writerToFinish.endSession(
                    atSourceTime: CMTime(
                        value: CMTimeValue(lastFrameIndex + 1), timescale: gridFrameRate))
            }

            audioInput?.markAsFinished()
            microphoneInput?.markAsFinished()
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
                logger.error(
                    "AssetWriter failed: \(error?.localizedDescription ?? "unknown error")")
                throw AssetWriterError.writingFailed(error)
            }

            isWriting = false
            resetTimingState()
            activeHDRPreset = .sdr
            tagBuffersWithHDRColorimetry = false

            logger.info(
                "AssetWriter finished writing \(self.frameCount) frames to: \(url.lastPathComponent)"
            )
            let videoFrameCount = frameCount
            frameCount = 0

            self.assetWriter = nil
            self.videoInput = nil
            self.pixelBufferAdaptor = nil
            self.audioInput = nil
            self.microphoneInput = nil
            self.outputURL = nil

            return (url, videoFrameCount)
        }
    }

    /// Cancels the current writing session
    func cancel() {
        lock.withLockUnchecked {
            assetWriter?.cancelWriting()
            isWriting = false
            resetTimingState()
            activeHDRPreset = .sdr
            tagBuffersWithHDRColorimetry = false
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

}

// MARK: - CaptureEngineSampleBufferDelegate

extension AssetWriter {

    func captureEngine(
        _ engine: CaptureEngine, didOutputVideoSampleBuffer sampleBuffer: CMSampleBuffer
    ) {
        appendVideoSample(sampleBuffer)
    }

    func captureEngine(
        _ engine: CaptureEngine, didOutputAudioSampleBuffer sampleBuffer: CMSampleBuffer
    ) {
        appendAudioSample(sampleBuffer)
    }

    func captureEngine(
        _ engine: CaptureEngine, didOutputMicrophoneSampleBuffer sampleBuffer: CMSampleBuffer
    ) {
        appendMicrophoneSample(sampleBuffer)
    }
}
