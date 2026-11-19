//
//  BetterCaptureApp.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 29.01.26.
//

import AppKit
import SwiftUI

@main
struct BetterCaptureApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var updaterService = UpdaterService()

    /// The recorder lives on the app delegate so URLs can be handled before the
    /// menu bar popover has ever been opened. See ``AppDelegate``.
    private var viewModel: RecorderViewModel { appDelegate.viewModel }

    var body: some Scene {
        // Menu bar extra - the primary interface in the comfortable layout.
        // Using .window style to support custom toggle switches.
        // The compact layout uses its own status item, see ``CompactBadgeCoordinator``
        MenuBarExtra(isInserted: .constant(viewModel.settings.layoutMode == .comfortable)) {
            MenuBarView(viewModel: viewModel)
                .task {
                    await viewModel.requestPermissionsOnLaunch()
                }
        } label: {
            MenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        // Settings window. A regular `Window` rather than a `Settings` scene, so
        // the split view gets a full-height sidebar and a standard toolbar
        Window("Settings", id: SettingsView.windowID) {
            SettingsView(
                settings: viewModel.settings,
                updaterService: updaterService,
                audioDeviceService: viewModel.audioDeviceService,
                cameraDeviceService: viewModel.cameraDeviceService,
                permissionService: viewModel.permissionService
            )
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}

/// The label shown in the menu bar (icon or duration timer)
struct MenuBarLabel: View {
    let viewModel: RecorderViewModel

    var body: some View {
        if viewModel.isPaused {
            Label("Paused", systemImage: "pause.fill")
                .foregroundStyle(.orange)
        } else if viewModel.isRecording {
            // Render the duration into a fixed-size image so the
            // NSStatusItem never recalculates its width on each tick.
            Image(nsImage: MenuBarTimerImage.make(
                text: viewModel.formattedDuration,
                recordingDuration: viewModel.recordingDuration
            ))
        } else {
            Image(systemName: "record.circle")
        }
    }
}
