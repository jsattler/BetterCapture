//
//  AssetWriterPauseTests.swift
//  BetterCaptureTests
//
//  Created by Joshua Sattler on 19.11.26.
//

import AVFoundation
import Testing
@testable import BetterCapture

/// Tests for removing paused intervals from the written timeline.
extension AssetWriterTests {

    @Test func pauseRemovesPausedTimeFromVideoTimeline() async throws {
        let settings = makeStore()
        settings.frameRate = .fps30

        let assetWriter = AssetWriter()
        try assetWriter.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try assetWriter.startWriting()

        for index in 0..<3 {
            assetWriter.appendVideoSample(
                try makeVideoSampleBuffer(at: CMTime(value: CMTimeValue(index), timescale: 30)))
        }

        assetWriter.pause(at: CMTime(value: 1, timescale: 10))
        assetWriter.appendVideoSample(try makeVideoSampleBuffer(at: CMTime(value: 1, timescale: 1)))
        assetWriter.resume(at: CMTime(value: 51, timescale: 10))
        assetWriter.appendVideoSample(
            try makeVideoSampleBuffer(at: CMTime(value: 154, timescale: 30)))

        let result = try await assetWriter.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }

        let times = try await videoPresentationTimes(of: result.url)
        #expect(times == (0..<5).map { CMTime(value: CMTimeValue($0), timescale: 30) })
    }

    @Test func pauseRemovesPausedTimeFromAudioTimeline() async throws {
        let settings = makeStore()
        settings.captureSystemAudio = true
        settings.audioCodec = .pcm

        let assetWriter = AssetWriter()
        try assetWriter.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try assetWriter.startWriting()

        for index in 0..<5 {
            let time = CMTime(value: CMTimeValue(index * 1024), timescale: 48000)
            assetWriter.appendAudioSample(try makeSilentAudioSampleBuffer(at: time))
        }

        assetWriter.pause(at: CMTime(value: 1, timescale: 10))
        assetWriter.appendAudioSample(
            try makeSilentAudioSampleBuffer(at: CMTime(value: 1, timescale: 1)))
        assetWriter.resume(at: CMTime(value: 51, timescale: 10))
        assetWriter.appendAudioSample(
            try makeSilentAudioSampleBuffer(at: CMTime(value: 245824, timescale: 48000)))

        let result = try await assetWriter.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }

        let track = try #require(await AVURLAsset(url: result.url).loadTracks(withMediaType: .audio).first)
        let duration = try await track.load(.timeRange).duration.seconds
        #expect(duration < 0.2)
    }

    /// The writer lays audio samples back to back and ignores their timestamps, so an
    /// overlap or gap where a pause was cut out would shift the rest of the track against
    /// the video. Once the 5s pause is removed, the first buffer after it starts at
    /// 0.102s (overlapping the last buffer before it, which ends at 0.1067s) or at
    /// 0.12s (leaving a gap).
    @Test(arguments: [244896, 245760], BetterCapture.AudioCodec.allCases)
    func audioStaysInSyncAcrossAPause(firstSampleAfterResume: Int, codec: BetterCapture.AudioCodec) async throws {
        let settings = makeStore()
        settings.captureSystemAudio = true
        settings.audioCodec = codec

        let assetWriter = AssetWriter()
        try assetWriter.setup(url: makeOutputURL(), settings: settings, videoSize: videoSize)
        try assetWriter.startWriting()

        for index in 0..<5 {
            let time = CMTime(value: CMTimeValue(index * 1024), timescale: 48000)
            assetWriter.appendAudioSample(try makeSilentAudioSampleBuffer(at: time))
        }

        assetWriter.pause(at: CMTime(value: 4800, timescale: 48000))
        assetWriter.resume(at: CMTime(value: 244800, timescale: 48000))

        for index in 0..<5 {
            let time = CMTime(
                value: CMTimeValue(firstSampleAfterResume + index * 1024), timescale: 48000)
            assetWriter.appendAudioSample(try makeSilentAudioSampleBuffer(at: time))
        }

        let result = try await assetWriter.finishWriting()
        defer { try? FileManager.default.removeItem(at: result.url) }

        let track = try #require(await AVURLAsset(url: result.url).loadTracks(withMediaType: .audio).first)
        let end = try await track.load(.timeRange).end
        let expectedEnd = CMTime(
            value: CMTimeValue(firstSampleAfterResume - 240000 + 5 * 1024), timescale: 48000)
        #expect(end == expectedEnd)
    }
}
