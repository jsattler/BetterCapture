//
//  BetterCaptureApp.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 29.01.26.
//

import AppKit
import KeyboardShortcuts
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
                    await viewModel.requestPermissionsOnLaunch()
                    registerKeyboardShortcuts()
                }
                .onOpenURL { url in
                    handleURL(url)
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

    // MARK: - URL Scheme

    private func handleURL(_ url: URL) {
        guard url.scheme == "bettercapture" else { return }

        switch url.host {
        case "toggle", "toggle-copy":
            let copyToClipboard = url.host == "toggle-copy"
            Task { @MainActor in
                if viewModel.isRecording {
                    await viewModel.stopRecording(copyToClipboard: copyToClipboard)
                } else {
                    switch ContentSelectionMode.current {
                    case .pickContent:
                        viewModel.presentPicker()
                    case .selectArea:
                        await viewModel.presentAreaSelection()
                    }
                }
            }
        case "open-recordings":
            Task { @MainActor in
                let settings = viewModel.settings
                let didStart = settings.startAccessingOutputDirectory()
                defer {
                    if didStart {
                        settings.stopAccessingOutputDirectory()
                    }
                }
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: settings.outputDirectory.path)
            }
        default:
            break
        }
    }

    // MARK: - Keyboard Shortcuts

    private func registerKeyboardShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [viewModel] in
            Task { @MainActor in
                await viewModel.toggleRecording()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .selectContent) { [viewModel] in
            Task { @MainActor in
                viewModel.presentPicker()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .selectArea) { [viewModel] in
            Task { @MainActor in
                await viewModel.presentAreaSelection()
            }
        }
    }
}

/// The label shown in the menu bar (icon or duration timer)
struct MenuBarLabel: View {
    let viewModel: RecorderViewModel

    var body: some View {
        if viewModel.isRecording {
            // Render the duration into a fixed-size image so the
            // NSStatusItem never recalculates its width on each tick.
            if let image = timerImage {
                Image(nsImage: image)
            }
        } else {
            Image(systemName: "record.circle")
        }
    }

    /// Renders the formatted duration into an ``NSImage`` with a stable
    /// width derived from the widest possible string for the current format.
    private var timerImage: NSImage? {
        let text = viewModel.formattedDuration

        // Use the widest possible string for the current format to
        // compute a stable size that won't change between ticks.
        let referenceText: String = if viewModel.recordingDuration >= 3600 {
            "0:00:00"
        } else {
            "00:00"
        }

        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]

        let referenceSize = (referenceText as NSString).size(withAttributes: attrs)
        let imageSize = NSSize(width: ceil(referenceSize.width), height: ceil(referenceSize.height))

        let textSize = (text as NSString).size(withAttributes: attrs)
        let origin = NSPoint(
            x: (imageSize.width - textSize.width) / 2,
            y: (imageSize.height - textSize.height) / 2
        )

        let image = NSImage(size: imageSize, flipped: false) { _ in
            (text as NSString).draw(at: origin, withAttributes: attrs)
            return true
        }
        image.isTemplate = true
        return image
    }
}
