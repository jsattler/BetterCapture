//
//  WindowResizePresetTests.swift
//  BetterCaptureTests
//
//  Created by Karel Busta on 13.05.26.
//

import CoreGraphics
import Testing
@testable import BetterCapture

@MainActor
struct WindowResizePresetTests {

    @Test func includesRequiredPresets() {
        let labels = WindowResizePreset.allCases.map(\.label)

        #expect(labels == [
            "9:16 720x1280",
            "9:16 1080x1920",
            "16:9 1280x720",
            "16:9 1920x1080",
            "1:1 1080x1080"
        ])
    }

    @Test func targetFrameUsesPresetSizeWhenItFits() {
        let frame = WindowResizeLayout.targetFrame(
            for: .landscape720,
            currentFrame: CGRect(x: 900, y: 700, width: 200, height: 200),
            visibleFrame: CGRect(x: 0, y: 0, width: 2_200, height: 1_800),
            margin: 0
        )

        #expect(frame == CGRect(x: 360, y: 440, width: 1_280, height: 720))
    }

    @Test func targetFrameClampsToVisibleFrame() {
        let frame = WindowResizeLayout.targetFrame(
            for: .landscape720,
            currentFrame: CGRect(x: 1_900, y: 400, width: 100, height: 100),
            visibleFrame: CGRect(x: 0, y: 0, width: 2_000, height: 1_200),
            margin: 0
        )

        #expect(frame == CGRect(x: 720, y: 90, width: 1_280, height: 720))
    }

    @Test func targetFrameScalesDownLargePreset() {
        let frame = WindowResizeLayout.targetFrame(
            for: .landscape1080,
            currentFrame: CGRect(x: 450, y: 300, width: 100, height: 100),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 700),
            margin: 0
        )

        #expect(frame == CGRect(x: 0, y: 69, width: 1_000, height: 562))
    }

    @Test func targetFrameHonorsMargin() {
        let frame = WindowResizeLayout.targetFrame(
            for: .landscape720,
            currentFrame: CGRect(x: 600, y: 350, width: 200, height: 200),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_400, height: 900)
        )

        #expect(frame == CGRect(x: 60, y: 90, width: 1_280, height: 720))
    }
}
