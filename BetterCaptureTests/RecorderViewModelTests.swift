//
//  RecorderViewModelTests.swift
//  BetterCaptureTests
//
//  Created by Joshua Sattler on 28.03.26.
//

import Testing
@testable import BetterCapture

/// Tests for RecorderViewModel's pure derived state and formatting.
///
/// These test the computed properties and initial state without
/// triggering any ScreenCaptureKit or system interactions.
@MainActor
struct RecorderViewModelTests {

    // MARK: - formattedDuration

    @Test func formattedDurationAtZero() {
        let vm = RecorderViewModel()
        #expect(vm.formattedDuration == "00:00")
    }

    // MARK: - Initial State

    @Test func initialStateIsIdle() {
        let vm = RecorderViewModel()
        #expect(vm.isRecording == false)
    }

    @Test func cannotStartRecordingWithoutContentFilter() {
        let vm = RecorderViewModel()
        #expect(vm.canStartRecording == false)
    }

    @Test func hasNoContentSelectedByDefault() {
        let vm = RecorderViewModel()
        #expect(vm.hasContentSelected == false)
    }

    @Test func isNotAreaSelectionByDefault() {
        let vm = RecorderViewModel()
        #expect(vm.isAreaSelection == false)
    }

    @Test func presenterOverlayInactiveByDefault() {
        let vm = RecorderViewModel()
        #expect(vm.isPresenterOverlayActive == false)
    }

    @Test func lastErrorIsNilByDefault() {
        let vm = RecorderViewModel()
        #expect(vm.lastError == nil)
    }

    @Test func recordingDurationIsZeroByDefault() {
        let vm = RecorderViewModel()
        #expect(vm.recordingDuration == 0)
    }
}
