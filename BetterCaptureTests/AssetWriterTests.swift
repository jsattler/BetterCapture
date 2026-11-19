//
//  AssetWriterTests.swift
//  BetterCaptureTests
//
//  Created by Krishna Ramaroson on 28.07.26.
//

import AVFoundation
import ScreenCaptureKit
import Testing
@testable import BetterCapture

/// Tests for the video frame count AssetWriter reports when finishing a recording.
///
/// A capture source that stops delivering frames - a disconnected display, for example -
/// while audio keeps flowing produces a file with audio tracks and no video track. The
/// frame count is what lets the caller detect that case.
@MainActor
@Suite(.serialized)
struct AssetWriterTests {

    let videoSize = CGSize(width: 640, height: 480)

    // MARK: - Tests

    @Test func audioOnlyRecordingReportsZeroVideoFrames() async throws {
        let settings = makeStore()
        settings.captureSystemAudio = true

        let assetWriter = AssetWriter()
        try assetWriter.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try assetWriter.startWriting()

        // Audio flows for the whole session, no video sample ever arrives
        for index in 0..<10 {
            let presentationTime = CMTime(value: CMTimeValue(index * 1024), timescale: 48000)
            assetWriter.appendAudioSample(try makeSilentAudioSampleBuffer(at: presentationTime))
        }

        let result = try await assetWriter.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }

        #expect(result.videoFrameCount == 0)

        // The recording is kept - audio is still worth saving - and it holds no video track
        #expect(FileManager.default.fileExists(atPath: result.url.path()))
        let videoTracks = try await AVURLAsset(url: result.url).loadTracks(withMediaType: .video)
        #expect(videoTracks.isEmpty)
    }

    @Test func recordingWithVideoReportsFramesWritten() async throws {
        let settings = makeStore()

        let assetWriter = AssetWriter()
        try assetWriter.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try assetWriter.startWriting()

        for index in 0..<5 {
            let presentationTime = CMTime(value: CMTimeValue(index), timescale: 60)
            assetWriter.appendVideoSample(try makeVideoSampleBuffer(at: presentationTime))
        }

        let result = try await assetWriter.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }

        #expect(result.videoFrameCount == 5)
    }

    @Test func cancelAfterFinishingDoesNotDeleteTheSavedRecording() async throws {
        let settings = makeStore()

        let assetWriter = AssetWriter()
        try assetWriter.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try assetWriter.startWriting()
        assetWriter.appendVideoSample(try makeVideoSampleBuffer(at: .zero))

        let result = try await assetWriter.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }

        // A failed setup for the next recording leaves the previous session's state in place,
        // and the recovery path cancels the writer. The saved file must survive that.
        assetWriter.cancel()

        #expect(FileManager.default.fileExists(atPath: result.url.path()))
    }

    @Test func recordingWithoutAnySampleThrows() async throws {
        let settings = makeStore()

        let assetWriter = AssetWriter()
        try assetWriter.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try assetWriter.startWriting()

        await #expect(throws: AssetWriterError.self) {
            try await assetWriter.finishWriting()
        }
    }

    // MARK: - Constant frame rate

    /// ScreenCaptureKit's `minimumFrameInterval` is a floor, not a cadence, so arrival
    /// times jitter by several milliseconds. Every frame must still land exactly on the
    /// grid, otherwise the file is variable frame rate and tools that resample to CFR
    /// collapse neighbouring frames into one slot.
    @Test func jitteredArrivalsSnapToTheFrameRateGrid() async throws {
        let settings = makeStore()
        settings.frameRate = .fps30

        let assetWriter = AssetWriter()
        try assetWriter.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try assetWriter.startWriting()

        // Nominal 33.3 ms spacing, jittered the way a real capture jitters
        for milliseconds in [0, 30, 63, 98, 137, 165] {
            let time = CMTime(value: CMTimeValue(milliseconds), timescale: 1000)
            assetWriter.appendVideoSample(try makeVideoSampleBuffer(at: time))
        }

        let result = try await assetWriter.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }

        let times = try await videoPresentationTimes(of: result.url)
        #expect(times == (0..<6).map { CMTime(value: CMTimeValue($0), timescale: 30) })
        #expect(result.videoFrameCount == 6)
    }

    /// A static screen makes ScreenCaptureKit stop delivering complete frames, which
    /// previously left second-long holes in the track. The gap must be filled with the
    /// last frame so the output stays CFR.
    @Test func stalledCaptureFillsTheGapWithTheLastFrame() async throws {
        let settings = makeStore()
        settings.frameRate = .fps30

        let assetWriter = AssetWriter()
        try assetWriter.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try assetWriter.startWriting()

        assetWriter.appendVideoSample(try makeVideoSampleBuffer(at: .zero))
        // One second of silence from the capture source
        assetWriter.appendVideoSample(try makeVideoSampleBuffer(at: CMTime(value: 1, timescale: 1)))

        let result = try await assetWriter.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }

        let times = try await videoPresentationTimes(of: result.url)
        #expect(times == (0...30).map { CMTime(value: CMTimeValue($0), timescale: 30) })
        #expect(result.videoFrameCount == 31)
    }

    /// Filling is capped so a very long stall cannot block the capture queue.
    @Test func fillIsCappedForVeryLongStalls() async throws {
        let settings = makeStore()
        settings.frameRate = .fps30

        let assetWriter = AssetWriter()
        try assetWriter.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try assetWriter.startWriting()

        assetWriter.appendVideoSample(try makeVideoSampleBuffer(at: .zero))
        // 20 s stall against a 10 s fill cap
        assetWriter.appendVideoSample(try makeVideoSampleBuffer(at: CMTime(value: 20, timescale: 1)))

        let result = try await assetWriter.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }

        // The first frame, then 300 frames of catch-up: 299 filled plus the frame that
        // ended the stall. The 300 slots before that are skipped outright.
        #expect(result.videoFrameCount == 301)

        let times = try await videoPresentationTimes(of: result.url)
        #expect(times.first == .zero)
        #expect(times.last == CMTime(value: 600, timescale: 30))
        #expect(isStrictlyIncreasing(times))
    }

    /// Two frames inside the same grid slot would produce a duplicate timestamp, which
    /// is exactly what breaks downstream muxers.
    @Test func framesLandingInTheSameSlotAreDropped() async throws {
        let settings = makeStore()
        settings.frameRate = .fps30

        let assetWriter = AssetWriter()
        try assetWriter.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try assetWriter.startWriting()

        assetWriter.appendVideoSample(try makeVideoSampleBuffer(at: .zero))
        // 10 ms later, well inside the 33.3 ms slot
        assetWriter.appendVideoSample(try makeVideoSampleBuffer(at: CMTime(value: 10, timescale: 1000)))

        let result = try await assetWriter.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }

        #expect(result.videoFrameCount == 1)
    }

    /// Presenter Overlay can emit an outright non-monotonic timestamp. One of those used
    /// to fail the writer permanently.
    @Test func nonMonotonicTimestampsDoNotFailTheWriter() async throws {
        let settings = makeStore()
        settings.frameRate = .fps30

        let assetWriter = AssetWriter()
        try assetWriter.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try assetWriter.startWriting()

        for milliseconds in [0, 33, 67, 20, 100] {
            let time = CMTime(value: CMTimeValue(milliseconds), timescale: 1000)
            assetWriter.appendVideoSample(try makeVideoSampleBuffer(at: time))
        }

        let result = try await assetWriter.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }

        // The out-of-order frame is dropped, the rest are written in order
        #expect(result.videoFrameCount == 4)
        let times = try await videoPresentationTimes(of: result.url)
        #expect(isStrictlyIncreasing(times))
    }

    // MARK: - Track origin

    /// Audio usually arrives before the first complete video frame. Both tracks must
    /// still resolve to a common origin of zero.
    @Test func videoIsBackfilledWhenAudioOpensTheSession() async throws {
        let settings = makeStore()
        settings.captureSystemAudio = true
        settings.audioCodec = .pcm
        settings.frameRate = .fps30

        let assetWriter = AssetWriter()
        try assetWriter.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try assetWriter.startWriting()

        // Audio anchors the session, video only starts 100 ms later
        assetWriter.appendAudioSample(try makeSilentAudioSampleBuffer(at: .zero))
        assetWriter.appendVideoSample(
            try makeVideoSampleBuffer(at: CMTime(value: 100, timescale: 1000)))

        let result = try await assetWriter.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }

        // Slots 0, 1 and 2 are back-filled so the video track also starts at zero
        #expect(result.videoFrameCount == 4)
        let times = try await videoPresentationTimes(of: result.url)
        #expect(times.first == .zero)
    }

    /// A microphone can take hundreds of milliseconds to start delivering samples. The
    /// head of the track is padded with silence so it still begins at zero, which is
    /// what keeps concatenated recordings in sync.
    @Test func lateMicrophoneIsPaddedWithSilence() async throws {
        let settings = makeStore()
        settings.captureSystemAudio = true
        settings.captureMicrophone = true
        settings.audioCodec = .pcm
        settings.frameRate = .fps30

        let assetWriter = AssetWriter()
        try assetWriter.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try assetWriter.startWriting()

        assetWriter.appendVideoSample(try makeVideoSampleBuffer(at: .zero))
        assetWriter.appendAudioSample(try makeSilentAudioSampleBuffer(at: .zero))

        // Microphone spins up 324 ms late, as measured on a real recording
        let micStart = CMTime(value: 324, timescale: 1000)
        for index in 0..<10 {
            let offset = CMTime(value: CMTimeValue(index * 1024), timescale: 48000)
            assetWriter.appendMicrophoneSample(
                try makeSilentAudioSampleBuffer(at: micStart + offset))
        }

        let result = try await assetWriter.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }

        let asset = AVURLAsset(url: result.url)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        #expect(audioTracks.count == 2)

        for track in audioTracks {
            let timeRange = try await track.load(.timeRange)
            #expect(timeRange.start == .zero)
        }
    }

    // MARK: - Helpers

    private func isStrictlyIncreasing(_ times: [CMTime]) -> Bool {
        zip(times, times.dropFirst()).allSatisfy { $0 < $1 }
    }

    /// Reads back every video frame's presentation timestamp, in presentation order.
    ///
    /// Decoding rather than reading compressed samples keeps the output one buffer per
    /// frame in presentation order, free of the container's edit and marker buffers.
    func videoPresentationTimes(of url: URL) async throws -> [CMTime] {
        let asset = AVURLAsset(url: url)
        let track = try #require(await asset.loadTracks(withMediaType: .video).first)

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
        )
        reader.add(output)
        #expect(reader.startReading())

        var times: [CMTime] = []
        while let sample = output.copyNextSampleBuffer() {
            guard CMSampleBufferGetNumSamples(sample) > 0 else { continue }
            times.append(CMSampleBufferGetPresentationTimeStamp(sample))
        }

        return times
    }

    /// Creates a SettingsStore backed by a fresh, empty UserDefaults suite.
    func makeStore() -> SettingsStore {
        let suiteName = "com.sattlerjoshua.BetterCaptureTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return SettingsStore(defaults: defaults)
    }

    func makeOutputURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")
    }

    /// Creates a buffer of silent 48 kHz stereo audio.
    func makeSilentAudioSampleBuffer(at presentationTime: CMTime) throws -> CMSampleBuffer {
        let frameCount: AVAudioFrameCount = 1024

        let format = try #require(
            AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48000, channels: 2, interleaved: true)
        )
        let pcmBuffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
        pcmBuffer.frameLength = frameCount

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 48000),
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        let createStatus = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format.formatDescription,
            sampleCount: CMItemCount(frameCount),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )
        #expect(createStatus == noErr)

        let buffer = try #require(sampleBuffer)
        let attachStatus = CMSampleBufferSetDataBufferFromAudioBufferList(
            buffer,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: pcmBuffer.mutableAudioBufferList
        )
        #expect(attachStatus == noErr)

        return buffer
    }

    /// Creates an empty BGRA video frame marked complete, as ScreenCaptureKit would deliver it.
    func makeVideoSampleBuffer(at presentationTime: CMTime) throws -> CMSampleBuffer {
        var pixelBuffer: CVPixelBuffer?
        let pixelBufferStatus = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(videoSize.width),
            Int(videoSize.height),
            kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey as String: [:] as CFDictionary] as CFDictionary,
            &pixelBuffer
        )
        #expect(pixelBufferStatus == kCVReturnSuccess)
        let imageBuffer = try #require(pixelBuffer)

        var formatDescription: CMFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: imageBuffer,
            formatDescriptionOut: &formatDescription
        )
        #expect(formatStatus == noErr)

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 60),
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )

        let videoFormat = try #require(formatDescription)

        var sampleBuffer: CMSampleBuffer?
        let createStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: imageBuffer,
            formatDescription: videoFormat,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        #expect(createStatus == noErr)
        let buffer = try #require(sampleBuffer)

        // appendVideoSample only accepts frames the capture engine marked complete
        let attachments = try #require(
            CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true) as? [NSMutableDictionary]
        )
        let attachment = try #require(attachments.first)
        attachment[SCStreamFrameInfo.status.rawValue] = SCFrameStatus.complete.rawValue

        return buffer
    }
}
