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
    @State private var toolService = CommandLineToolService()

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

            Section {
                CommandLineToolStatusRow(toolService: toolService)
                LabeledContent("Location") {
                    Text(CommandLineToolInstaller.toolURL.path(percentEncoded: false))
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } header: {
                Text("Command-Line Tool")
            } footer: {
                SettingsFooter("AI agents can run bettercapture skill show to learn how to use it.")
            }
        }
        .formStyle(.grouped)
        .task {
            await toolService.refresh()
        }
    }
}

/// Whether `bettercapture` can be run from a terminal, and how to fix it if it can't
private struct CommandLineToolStatusRow: View {
    let toolService: CommandLineToolService

    var body: some View {
        switch toolService.status {
        case .checking:
            LabeledContent("Status") {
                ProgressView()
                    .controlSize(.small)
            }
        case .available:
            LabeledContent("Status") {
                Label("Ready to use in Terminal", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        case .otherCopy(let path):
            LabeledContent("Status") {
                Text("bettercapture runs another copy at \(path)")
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        case .notOnPath:
            VStack(alignment: .leading) {
                LabeledContent("Status") {
                    Text("Not found in your PATH")
                        .foregroundStyle(.secondary)
                }
                Text("Add this line to \(toolService.pathSetup.file), then open a new terminal window:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(toolService.pathSetup.line)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                Button("Check Again") {
                    Task { await toolService.refresh() }
                }
            }
        }
    }
}
