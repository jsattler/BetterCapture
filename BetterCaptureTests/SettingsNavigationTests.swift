//
//  SettingsNavigationTests.swift
//  BetterCaptureTests
//

import Testing
@testable import BetterCapture

struct SettingsNavigationTests {

    @Test func startsOnGeneralWithNoHistory() {
        let navigation = SettingsNavigation()
        #expect(navigation.current == .general)
        #expect(!navigation.canGoBack)
        #expect(!navigation.canGoForward)
    }

    @Test func visitingSamePaneDoesNotAddHistory() {
        var navigation = SettingsNavigation()
        navigation.visit(.general)
        #expect(!navigation.canGoBack)
    }

    @Test func backAndForwardRestorePanes() {
        var navigation = SettingsNavigation()
        navigation.visit(.video)
        navigation.visit(.audio)

        navigation.goBack()
        #expect(navigation.current == .video)
        navigation.goBack()
        #expect(navigation.current == .general)
        #expect(!navigation.canGoBack)

        navigation.goForward()
        #expect(navigation.current == .video)
        navigation.goForward()
        #expect(navigation.current == .audio)
        #expect(!navigation.canGoForward)
    }

    @Test func visitingClearsForwardHistory() {
        var navigation = SettingsNavigation()
        navigation.visit(.video)
        navigation.goBack()
        navigation.visit(.shortcuts)
        #expect(!navigation.canGoForward)
        #expect(navigation.current == .shortcuts)
    }
}
