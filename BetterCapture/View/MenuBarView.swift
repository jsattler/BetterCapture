//
//  MenuBarView.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 29.01.26.
//

import SwiftUI
import ScreenCaptureKit

/// The main menu bar interface for BetterCapture
struct MenuBarView: View {
    @Bindable var viewModel: RecorderViewModel
    @Environment(\.openSettings) private var openSettings
    @State private var currentPreview: NSImage?

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isRecording {
                recordingContent
            } else {
                idleContent
            }
        }
        .frame(width: 320)
    }

    // MARK: - Idle State Content

    private var idleContent: some View {
        VStack(spacing: 0) {
            // Start Recording Button
            MenuBarActionButton(
                title: "Start Recording",
                systemImage: "record.circle",
                accentColor: .green,
                isDisabled: !viewModel.canStartRecording
            ) {
                Task {
                    await viewModel.startRecording()
                }
            }
            .padding(.top, 8)

            MenuBarDivider()

            // Content Selection
            ContentSharingPickerButton(viewModel: viewModel)

            // Preview thumbnail below the content selection button
            if viewModel.hasContentSelected {
                PreviewThumbnailView(previewImage: currentPreview)
                    .onChange(of: viewModel.previewService.previewImage) { _, newImage in
                        currentPreview = newImage
                    }
                    .onAppear {
                        currentPreview = viewModel.previewService.previewImage
                    }
            }

            MenuBarDivider()

            // Settings Sections (no divider between them - section headers provide separation)
            VideoSettingsSection(settings: viewModel.settings)

            AudioSettingsSection(
                settings: viewModel.settings,
                audioDeviceService: viewModel.audioDeviceService
            )

            MenuBarDivider()

            // Bottom Actions
            MenuBarActionButton(title: "Open Output Folder", systemImage: "folder") {
                let settings = viewModel.settings
                let didStart = settings.startAccessingOutputDirectory()
                defer {
                    if didStart {
                        settings.stopAccessingOutputDirectory()
                    }
                }
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: settings.outputDirectory.path)
            }

            MenuBarActionButton(title: "Settings...", systemImage: "gear") {
                openSettings()
            }

            MenuBarActionButton(title: "Quit...", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: - Recording State Content

    private var recordingContent: some View {
        VStack(spacing: 0) {
            // Combined Stop Recording Button with timer
            RecordingButton(
                duration: viewModel.formattedDuration
            ) {
                Task {
                    await viewModel.stopRecording()
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Menu Bar Action Button

/// A styled action button for menu bar window with hover effect
struct MenuBarActionButton: View {
    let title: String
    var systemImage: String? = nil
    var accentColor: Color = .primary
    var isDisabled: Bool = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage {
                    ZStack {
                        Circle()
                            .fill(.gray.opacity(0.2))
                            .frame(width: 24, height: 24)

                        Image(systemName: systemImage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(isDisabled ? Color.gray.opacity(0.3) : accentColor.opacity(0.8))
                    }
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isDisabled ? Color.gray.opacity(0.5) : Color.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered && !isDisabled ? accentColor.opacity(0.1) : .clear)
                .padding(.horizontal, 4)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Recording Button

/// A combined button that shows recording status and allows stopping
struct RecordingButton: View {
    let duration: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Pulsing red dot with stop icon
                ZStack {
                    Circle()
                        .fill(.gray.opacity(0.2))
                        .frame(width: 24, height: 24)

                    Image(systemName: "stop.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.red.opacity(0.8))
                }

                Text("Stop Recording")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Text(duration)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? .red.opacity(0.1) : .clear)
                .padding(.horizontal, 4)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Content Sharing Picker Button

/// A button that presents the system content sharing picker with hover effect
struct ContentSharingPickerButton: View {
    let viewModel: RecorderViewModel
    @State private var isHovered = false

    var body: some View {
        Button {
            viewModel.presentPicker()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(viewModel.hasContentSelected ? .blue.opacity(0.8) : .gray.opacity(0.2))
                        .frame(width: 24, height: 24)

                    Image(systemName: "rectangle.dashed")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(viewModel.hasContentSelected ? .white : .primary)
                }

                Text(viewModel.hasContentSelected ? "Change Selection..." : "Select Content...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? .gray.opacity(0.1) : .clear)
                .padding(.horizontal, 4)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview

#Preview {
    MenuBarView(viewModel: RecorderViewModel())
}
