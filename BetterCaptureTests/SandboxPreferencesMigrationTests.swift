//
//  SandboxPreferencesMigrationTests.swift
//  BetterCaptureTests
//
//  Created by Joshua Sattler on 19.11.26.
//

import Foundation
import Testing
@testable import BetterCapture

struct SandboxPreferencesMigrationTests {

    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.sattlerjoshua.BetterCaptureTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName) ?? .standard
    }

    private func writePreferences(_ values: [String: Any]) throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).plist")
        let data = try PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0)
        try data.write(to: url)
        return url
    }

    @Test func copiesContainerPreferences() throws {
        let defaults = makeDefaults()
        let source = try writePreferences(["frameRate": 30, "videoCodec": "hevc"])

        SandboxPreferencesMigration.migrateIfNeeded(into: defaults, from: source)

        #expect(defaults.integer(forKey: "frameRate") == 30)
        #expect(defaults.string(forKey: "videoCodec") == "hevc")
        #expect(defaults.bool(forKey: SandboxPreferencesMigration.completedKey))
    }

    @Test func keepsValuesAlreadySet() throws {
        let defaults = makeDefaults()
        defaults.set(60, forKey: "frameRate")
        let source = try writePreferences(["frameRate": 30])

        SandboxPreferencesMigration.migrateIfNeeded(into: defaults, from: source)

        #expect(defaults.integer(forKey: "frameRate") == 60)
    }

    @Test func runsOnlyOnce() throws {
        let defaults = makeDefaults()
        SandboxPreferencesMigration.migrateIfNeeded(into: defaults, from: try writePreferences([:]))

        SandboxPreferencesMigration.migrateIfNeeded(into: defaults, from: try writePreferences(["frameRate": 30]))

        #expect(defaults.object(forKey: "frameRate") == nil)
    }

    @Test func missingContainerMarksMigrationComplete() {
        let defaults = makeDefaults()
        let missing = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).plist")

        SandboxPreferencesMigration.migrateIfNeeded(into: defaults, from: missing)

        #expect(defaults.bool(forKey: SandboxPreferencesMigration.completedKey))
    }
}
