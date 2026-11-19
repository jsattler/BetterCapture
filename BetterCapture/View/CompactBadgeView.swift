//
//  CompactBadgeView.swift
//  BetterCapture
//

import SwiftUI

/// The draggable, pill-shaped badge shown in the compact layout.
///
/// Shows the main actions while idle, and stop and pause while recording.
/// It lives in a floating panel, see ``CompactBadgeCoordinator``.
/// Like a menu, it hides after an action.
///
/// Every action is a fixed-size tile so the badge always has a whole-point size.
/// The floating panel resizes itself to this view; a fractional size (e.g. 52.5 pt)
/// can't be matched by the window frame, which makes AppKit and SwiftUI resize
/// each other endlessly until the stack overflows.
struct CompactBadgeView: View {
    let viewModel: RecorderViewModel
    /// Hides the badge, called after an action
    let hide: () -> Void

    var body: some View {
        // Same spacing between tiles as around them, so the pill-shaped hover
        // highlights sit concentric to the badge
        HStack(spacing: 8) {
            if viewModel.isRecording {
                CompactBadgeRecordingControls(viewModel: viewModel, hide: hide)
            } else {
                CompactBadgeIdleControls(viewModel: viewModel, hide: hide)
            }
        }
        .buttonStyle(CompactBadgeButtonStyle())
        .padding(8)
        .modifier(CompactBadgeBackground())
        .contentShape(.capsule)
        .gesture(WindowDragGesture())
        .allowsWindowActivationEvents(true)
        .padding(8)
    }
}

// MARK: - Idle Controls

/// Start recording, content selection, settings and quit
private struct CompactBadgeIdleControls: View {
    let viewModel: RecorderViewModel
    let hide: () -> Void
    @Environment(\.openWindow) private var openWindow
    @AppStorage(ContentSelectionMode.storageKey) private var selectionMode: ContentSelectionMode = .pickContent

    var body: some View {
        if viewModel.permissionService.screenRecordingState != .granted {
            Button {
                hide()
                viewModel.permissionService.openScreenRecordingSettings()
            } label: {
                CompactBadgeTile(title: "Permission", systemImage: "exclamationmark.triangle.fill", tint: .orange)
            }
            .help("Screen Recording permission required")
        }

        Button {
            Task {
                await viewModel.startRecording()
            }
        } label: {
            CompactBadgeTile(title: "Record", systemImage: "record.circle.fill", tint: .red)
        }
        .disabled(!viewModel.canStartRecording)
        .help(viewModel.canStartRecording ? "Start Recording" : "Select content to record first")

        ForEach([ContentSelectionMode.pickContent, .selectArea], id: \.self) { mode in
            Button {
                select(mode)
            } label: {
                CompactBadgeTile(title: mode.shortLabel, systemImage: mode.icon)
            }
            .help(mode.label)
        }

        Button {
            hide()
            NSApplication.shared.activate(ignoringOtherApps: true)
            openWindow(id: SettingsView.windowID)
        } label: {
            CompactBadgeTile(title: "Settings", systemImage: "gearshape")
        }

        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            CompactBadgeTile(title: "Quit", systemImage: "power")
        }
    }

    private func select(_ mode: ContentSelectionMode) {
        // Remember the mode so the `bettercapture://toggle` URL uses the same one
        selectionMode = mode
        hide()

        switch mode {
        case .pickContent:
            viewModel.presentPicker()
        case .selectArea:
            Task {
                await viewModel.presentAreaSelection()
            }
        }
    }
}

// MARK: - Recording Controls

/// Stop (captioned with the elapsed time) and pause/resume
private struct CompactBadgeRecordingControls: View {
    let viewModel: RecorderViewModel
    let hide: () -> Void

    var body: some View {
        Button {
            Task {
                await viewModel.stopRecording()
            }
        } label: {
            CompactBadgeTile(title: viewModel.formattedDuration, systemImage: "stop.circle.fill", tint: .red)
                .monospacedDigit()
        }
        .help("Stop Recording")

        Button {
            hide()
            viewModel.togglePause()
        } label: {
            CompactBadgeTile(
                title: viewModel.isPaused ? "Resume" : "Pause",
                systemImage: viewModel.isPaused ? "play.circle" : "pause.circle"
            )
        }
    }
}

// MARK: - Tile

/// An icon with a caption below, at a fixed whole-point size
private struct CompactBadgeTile: View {
    let title: String
    let systemImage: String
    var tint: Color = .primary

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
            Text(title)
                .font(.caption)
                .lineLimit(1)
        }
        .frame(width: 64, height: 48)
    }
}

// MARK: - Button Style

/// Highlights the tile on hover and press, dims it when disabled
private struct CompactBadgeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CompactBadgeButton(configuration: configuration)
    }
}

private struct CompactBadgeButton: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .opacity(isEnabled ? 1 : 0.4)
            .background(
                .fill.opacity(configuration.isPressed ? 1 : (isHovered && isEnabled ? 0.6 : 0)),
                in: .capsule
            )
            .contentShape(.capsule)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Background

/// Liquid Glass on macOS 26, a material capsule on earlier versions
private struct CompactBadgeBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(.regularMaterial, in: .capsule)
                .shadow(radius: 4)
        }
    }
}

// MARK: - Preview

#Preview {
    CompactBadgeView(viewModel: RecorderViewModel()) {}
}
