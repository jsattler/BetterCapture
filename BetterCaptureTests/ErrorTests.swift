//
//  ErrorTests.swift
//  BetterCaptureTests
//
//  Created by Joshua Sattler on 28.03.26.
//

import Testing
import Foundation
@testable import BetterCapture

/// Tests that all error types provide meaningful user-facing descriptions.
struct ErrorTests {

    // MARK: - AssetWriterError

    @Test func assetWriterErrorDescriptions() {
        let cases: [AssetWriterError] = [
            .failedToCreateWriter,
            .writerNotReady,
            .failedToStartWriting(nil),
            .writingFailed(nil),
            .noOutputURL,
            .noFramesWritten,
        ]

        for error in cases {
            let description = error.errorDescription
            #expect(description != nil)
            #expect(description?.isEmpty == false)
        }
    }

    @Test func assetWriterErrorWithUnderlyingError() {
        let underlying = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "test error"])
        let error1 = AssetWriterError.failedToStartWriting(underlying)
        let error2 = AssetWriterError.writingFailed(underlying)

        #expect(error1.errorDescription?.contains("test error") == true)
        #expect(error2.errorDescription?.contains("test error") == true)
    }

    // MARK: - CaptureError

    @Test func captureErrorDescriptions() {
        let cases: [CaptureError] = [
            .noContentFilterSelected,
            .failedToCreateStream,
            .captureAlreadyRunning,
            .screenRecordingPermissionDenied,
            .microphonePermissionDenied,
        ]

        for error in cases {
            let description = error.errorDescription
            #expect(description != nil)
            #expect(description?.isEmpty == false)
        }
    }

    @Test func captureErrorScreenRecordingMentionsPermission() {
        let error = CaptureError.screenRecordingPermissionDenied
        #expect(error.errorDescription?.localizedStandardContains("permission") == true)
    }

    @Test func captureErrorMicrophoneMentionsPermission() {
        let error = CaptureError.microphonePermissionDenied
        #expect(error.errorDescription?.localizedStandardContains("permission") == true)
    }
}
