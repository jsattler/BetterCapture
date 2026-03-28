//
//  VideoQualityTests.swift
//  BetterCaptureTests
//
//  Created by Joshua Sattler on 28.03.26.
//

import Testing
@testable import BetterCapture

struct VideoQualityTests {

    // MARK: - h264BitsPerPixel

    @Test func h264BitsPerPixel() {
        #expect(VideoQuality.low.h264BitsPerPixel == 0.04)
        #expect(VideoQuality.medium.h264BitsPerPixel == 0.15)
        #expect(VideoQuality.high.h264BitsPerPixel == 0.6)
    }

    // MARK: - hevcBitsPerPixel

    @Test func hevcBitsPerPixel() {
        #expect(VideoQuality.low.hevcBitsPerPixel == 0.02)
        #expect(VideoQuality.medium.hevcBitsPerPixel == 0.1)
        #expect(VideoQuality.high.hevcBitsPerPixel == 0.4)
    }

    // MARK: - bitsPerPixel(for:)

    @Test func bitsPerPixelForH264() {
        #expect(VideoQuality.low.bitsPerPixel(for: .h264) == 0.04)
        #expect(VideoQuality.medium.bitsPerPixel(for: .h264) == 0.15)
        #expect(VideoQuality.high.bitsPerPixel(for: .h264) == 0.6)
    }

    @Test func bitsPerPixelForHEVC() {
        #expect(VideoQuality.low.bitsPerPixel(for: .hevc) == 0.02)
        #expect(VideoQuality.medium.bitsPerPixel(for: .hevc) == 0.1)
        #expect(VideoQuality.high.bitsPerPixel(for: .hevc) == 0.4)
    }

    @Test func bitsPerPixelReturnsNilForProRes() {
        for quality in VideoQuality.allCases {
            #expect(quality.bitsPerPixel(for: .proRes422) == nil)
            #expect(quality.bitsPerPixel(for: .proRes4444) == nil)
        }
    }

    // MARK: - HEVC is more efficient than H.264

    @Test func hevcMoreEfficientThanH264() {
        for quality in VideoQuality.allCases {
            #expect(quality.hevcBitsPerPixel < quality.h264BitsPerPixel)
        }
    }

    // MARK: - Identifiable & RawValue

    @Test func rawValues() {
        #expect(VideoQuality.low.rawValue == "Low")
        #expect(VideoQuality.medium.rawValue == "Medium")
        #expect(VideoQuality.high.rawValue == "High")
    }

    @Test func identifiable() {
        for quality in VideoQuality.allCases {
            #expect(quality.id == quality.rawValue)
        }
    }

    @Test func allCasesCount() {
        #expect(VideoQuality.allCases.count == 3)
    }
}
