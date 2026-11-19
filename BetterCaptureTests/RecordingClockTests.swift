//
//  RecordingClockTests.swift
//  BetterCaptureTests
//
//  Created by Joshua Sattler on 19.11.26.
//

import Foundation
import Testing
@testable import BetterCapture

struct RecordingClockTests {

    private let start = Date(timeIntervalSinceReferenceDate: 0)

    @Test func elapsedCountsTimeSinceStart() {
        let clock = RecordingClock(startedAt: start)
        #expect(clock.elapsed(at: start + 10) == 10)
    }

    @Test func elapsedFreezesWhilePaused() {
        var clock = RecordingClock(startedAt: start)
        clock.pause(at: start + 10)
        #expect(clock.elapsed(at: start + 25) == 10)
    }

    @Test func elapsedExcludesPausedTimeAfterResume() {
        var clock = RecordingClock(startedAt: start)
        clock.pause(at: start + 10)
        clock.resume(at: start + 25)
        #expect(clock.elapsed(at: start + 30) == 15)
    }

    @Test func repeatedPauseKeepsTheFirstPauseTime() {
        var clock = RecordingClock(startedAt: start)
        clock.pause(at: start + 10)
        clock.pause(at: start + 20)
        clock.resume(at: start + 30)
        #expect(clock.elapsed(at: start + 30) == 10)
    }

    @Test func resumeWithoutPauseIsIgnored() {
        var clock = RecordingClock(startedAt: start)
        clock.resume(at: start + 10)
        #expect(clock.elapsed(at: start + 10) == 10)
    }
}
