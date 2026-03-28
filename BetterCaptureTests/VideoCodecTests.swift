//
//  VideoCodecTests.swift
//  BetterCaptureTests
//
//  Created by Joshua Sattler on 28.03.26.
//

import Testing
import CoreVideo
@testable import BetterCapture

struct VideoCodecTests {

    // MARK: - supportsAlphaChannel

    @Test func supportsAlphaChannel() {
        #expect(VideoCodec.h264.supportsAlphaChannel == false)
        #expect(VideoCodec.hevc.supportsAlphaChannel == true)
        #expect(VideoCodec.proRes422.supportsAlphaChannel == false)
        #expect(VideoCodec.proRes4444.supportsAlphaChannel == true)
    }

    // MARK: - alwaysHasAlpha

    @Test func alwaysHasAlpha() {
        #expect(VideoCodec.h264.alwaysHasAlpha == false)
        #expect(VideoCodec.hevc.alwaysHasAlpha == false)
        #expect(VideoCodec.proRes422.alwaysHasAlpha == false)
        #expect(VideoCodec.proRes4444.alwaysHasAlpha == true)
    }

    // MARK: - canToggleAlpha

    @Test func canToggleAlpha() {
        #expect(VideoCodec.h264.canToggleAlpha == false)
        #expect(VideoCodec.hevc.canToggleAlpha == true)
        #expect(VideoCodec.proRes422.canToggleAlpha == false)
        #expect(VideoCodec.proRes4444.canToggleAlpha == false)
    }

    // MARK: - supportsHDR

    @Test func supportsHDR() {
        #expect(VideoCodec.h264.supportsHDR == false)
        #expect(VideoCodec.hevc.supportsHDR == true)
        #expect(VideoCodec.proRes422.supportsHDR == true)
        #expect(VideoCodec.proRes4444.supportsHDR == true)
    }

    // MARK: - hdrPixelFormat

    @Test func hdrPixelFormat() {
        #expect(VideoCodec.h264.hdrPixelFormat == kCVPixelFormatType_32BGRA)
        #expect(VideoCodec.hevc.hdrPixelFormat == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)
        #expect(VideoCodec.proRes422.hdrPixelFormat == kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange)
        #expect(VideoCodec.proRes4444.hdrPixelFormat == kCVPixelFormatType_64RGBAHalf)
    }

    // MARK: - supportsQualitySetting

    @Test func supportsQualitySetting() {
        #expect(VideoCodec.h264.supportsQualitySetting == true)
        #expect(VideoCodec.hevc.supportsQualitySetting == true)
        #expect(VideoCodec.proRes422.supportsQualitySetting == false)
        #expect(VideoCodec.proRes4444.supportsQualitySetting == false)
    }

    // MARK: - Identifiable & RawValue

    @Test func rawValues() {
        #expect(VideoCodec.h264.rawValue == "H.264")
        #expect(VideoCodec.hevc.rawValue == "H.265")
        #expect(VideoCodec.proRes422.rawValue == "ProRes 422")
        #expect(VideoCodec.proRes4444.rawValue == "ProRes 4444")
    }

    @Test func identifiable() {
        for codec in VideoCodec.allCases {
            #expect(codec.id == codec.rawValue)
        }
    }

    @Test func allCasesCount() {
        #expect(VideoCodec.allCases.count == 4)
    }
}
