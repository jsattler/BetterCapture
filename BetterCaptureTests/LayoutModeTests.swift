//
//  LayoutModeTests.swift
//  BetterCaptureTests
//

import Testing
import Foundation
@testable import BetterCapture

@MainActor
struct LayoutModeTests {

    private func makeStore() -> SettingsStore {
        let suiteName = "com.sattlerjoshua.BetterCaptureTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return SettingsStore(defaults: defaults)
    }

    @Test func defaultLayoutIsComfortable() {
        #expect(makeStore().layoutMode == .comfortable)
    }

    @Test func layoutModePersists() {
        let suiteName = "com.sattlerjoshua.BetterCaptureTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        SettingsStore(defaults: defaults).layoutMode = .compact

        #expect(SettingsStore(defaults: defaults).layoutMode == .compact)
    }
}
