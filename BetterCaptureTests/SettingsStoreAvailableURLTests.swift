//
//  SettingsStoreAvailableURLTests.swift
//  BetterCaptureTests
//
//  Created by Joshua Sattler on 20.11.26.
//

import Foundation
import Testing
@testable import BetterCapture

/// Tests for how SettingsStore keeps recordings started at the same time from sharing a file
@MainActor
struct SettingsStoreAvailableURLTests {

    @Test func availableURLKeepsAFreeURL() throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appending(path: "Recording.mov")
        #expect(SettingsStore.availableURL(for: url) == url)
    }

    @Test func availableURLNumbersTakenURLs() throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appending(path: "Recording.mov")
        FileManager.default.createFile(atPath: url.path(percentEncoded: false), contents: nil)
        FileManager.default.createFile(atPath: directory.appending(path: "Recording 2.mov").path(percentEncoded: false), contents: nil)

        #expect(SettingsStore.availableURL(for: url).lastPathComponent == "Recording 3.mov")
    }
}
