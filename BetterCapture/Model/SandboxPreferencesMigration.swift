//
//  SandboxPreferencesMigration.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 19.11.26.
//

import Foundation

/// Copies preferences written by earlier, sandboxed versions of the app into the
/// regular preferences domain.
///
/// A sandboxed app stores its `UserDefaults` inside its container. Once the sandbox is
/// removed, `UserDefaults.standard` reads `~/Library/Preferences` instead, so without this
/// migration users would lose their settings, keyboard shortcuts and output folder.
enum SandboxPreferencesMigration {

    /// The key marking that the migration has run, so it only ever runs once.
    static let completedKey = "didMigrateSandboxPreferences"

    /// The preferences file the sandboxed app wrote for this bundle identifier.
    static var containerPreferencesURL: URL {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.sattlerjoshua.BetterCapture"
        return URL.homeDirectory.appending(
            path: "Library/Containers/\(bundleID)/Data/Library/Preferences/\(bundleID).plist"
        )
    }

    /// Copies every key from the container preferences that isn't already set.
    /// - Parameters:
    ///   - defaults: The defaults to migrate into.
    ///   - sourceURL: The sandboxed app's preferences file.
    static func migrateIfNeeded(
        into defaults: UserDefaults = .standard,
        from sourceURL: URL = containerPreferencesURL
    ) {
        guard !defaults.bool(forKey: completedKey) else { return }
        defer { defaults.set(true, forKey: completedKey) }

        guard
            let data = try? Data(contentsOf: sourceURL),
            let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return }

        for (key, value) in values where defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
        }
    }
}
