//
//  FrameRateTests.swift
//  BetterCaptureTests
//
//  Created by Joshua Sattler on 28.03.26.
//

import Testing
@testable import BetterCapture

struct FrameRateTests {

    // MARK: - displayName

    @Test func displayNameNative() {
        #expect(FrameRate.native.displayName == "Native")
    }

    @Test func displayNameExplicitRates() {
        #expect(FrameRate.fps24.displayName == "24 fps")
        #expect(FrameRate.fps30.displayName == "30 fps")
        #expect(FrameRate.fps60.displayName == "60 fps")
    }

    // MARK: - effectiveFrameRate

    @Test func effectiveFrameRateNativeIs60() {
        #expect(FrameRate.native.effectiveFrameRate == 60.0)
    }

    @Test func effectiveFrameRateExplicitRates() {
        #expect(FrameRate.fps24.effectiveFrameRate == 24.0)
        #expect(FrameRate.fps30.effectiveFrameRate == 30.0)
        #expect(FrameRate.fps60.effectiveFrameRate == 60.0)
    }

    // MARK: - Identifiable & RawValue

    @Test func rawValues() {
        #expect(FrameRate.native.rawValue == 0)
        #expect(FrameRate.fps24.rawValue == 24)
        #expect(FrameRate.fps30.rawValue == 30)
        #expect(FrameRate.fps60.rawValue == 60)
    }

    @Test func identifiable() {
        for rate in FrameRate.allCases {
            #expect(rate.id == rate.rawValue)
        }
    }

    @Test func allCasesCount() {
        #expect(FrameRate.allCases.count == 4)
    }
}
