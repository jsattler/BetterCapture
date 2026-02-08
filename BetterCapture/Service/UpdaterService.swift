//
//  UpdaterService.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 08.02.26.
//

import Foundation
import Sparkle

/// Wraps Sparkle's updater controller for use in SwiftUI
///
/// This service owns the `SPUStandardUpdaterController` and exposes
/// observable state for whether the user can check for updates, and
/// a binding to the automatic-check preference managed by Sparkle.
@MainActor
@Observable
final class UpdaterService {

    // MARK: - Properties

    /// Whether the updater is currently able to check for updates
    private(set) var canCheckForUpdates = false

    /// The underlying Sparkle updater controller
    private let controller: SPUStandardUpdaterController

    /// KVO observation for `canCheckForUpdates`
    private var canCheckObservation: NSKeyValueObservation?

    /// Convenience accessor for the updater
    var updater: SPUUpdater {
        controller.updater
    }

    /// Whether Sparkle should automatically check for updates.
    /// This directly reads/writes Sparkle's own user-defaults-backed property.
    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    // MARK: - Initialization

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        // Observe Sparkle's canCheckForUpdates via KVO
        canCheckObservation = updater.observe(
            \.canCheckForUpdates,
            options: [.initial, .new]
        ) { [weak self] updater, _ in
            MainActor.assumeIsolated {
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }
    }

    // MARK: - Actions

    /// Triggers a user-initiated check for updates
    func checkForUpdates() {
        updater.checkForUpdates()
    }
}
