//
//  CompactBadgeVisibilityTests.swift
//  BetterCaptureTests
//

import Testing
@testable import BetterCapture

struct CompactBadgeVisibilityTests {

    @Test func startsHidden() {
        #expect(!CompactBadgeVisibility().isVisible(layoutMode: .compact))
    }

    @Test func toggleShowsAndHides() {
        var visibility = CompactBadgeVisibility()

        visibility.toggle()
        #expect(visibility.isVisible(layoutMode: .compact))

        visibility.toggle()
        #expect(!visibility.isVisible(layoutMode: .compact))
    }

    @Test func neverVisibleInComfortableLayout() {
        var visibility = CompactBadgeVisibility()
        visibility.toggle()
        #expect(!visibility.isVisible(layoutMode: .comfortable))
    }

    @Test func hideAfterAction() {
        var visibility = CompactBadgeVisibility()
        visibility.toggle()

        visibility.hide()

        #expect(!visibility.isVisible(layoutMode: .compact))
    }

    @Test func recordingStateChangeHides() {
        var visibility = CompactBadgeVisibility()
        visibility.toggle()

        visibility.recordingStateDidChange()

        #expect(!visibility.isVisible(layoutMode: .compact))
    }
}
