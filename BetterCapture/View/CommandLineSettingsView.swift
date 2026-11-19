//
//  CommandLineSettingsView.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 20.11.26.
//

import SwiftUI

/// Settings for the `bettercapture` command-line tool
struct CommandLineSettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Allow Command-Line Control", isOn: $settings.allowCommandLineControl)
            } footer: {
                SettingsFooter(
                    "Lets scripts and AI agents start and stop recordings with the bettercapture command, without the picker. "
                        + "Any app on this Mac can then record your screen through BetterCapture, so only turn this on if you need it."
                )
            }
        }
        .formStyle(.grouped)
    }
}
