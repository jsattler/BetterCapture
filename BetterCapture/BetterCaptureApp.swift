//
//  BetterCaptureApp.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 29.01.26.
//

import SwiftUI

@main
struct BetterCaptureApp: App {
    @State private var viewModel = RecorderViewModel()
    @State private var updaterService = UpdaterService()

    var body: some Scene {
        // Menu bar extra - the primary interface
        // Using .window style to support custom toggle switches
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
                .task {
                    // Request permissions on first app launch
                    await viewModel.requestPermissionsOnLaunch()
                }
        } label: {
            MenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        // Settings window
        Settings {
            SettingsView(settings: viewModel.settings, updaterService: updaterService)
        }
    }
}

/// The label shown in the menu bar (icon or duration timer)
struct MenuBarLabel: View {
    let viewModel: RecorderViewModel

    var body: some View {
        if viewModel.isRecording {
            // Show recording duration as text
            Text(viewModel.formattedDuration)
                .monospacedDigit()
        } else {
            // Show app icon
            Image(systemName: "record.circle")
        }
    }
}
