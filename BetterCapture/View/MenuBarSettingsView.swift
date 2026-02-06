//
//  MenuBarSettingsView.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 02.02.26.
//

import SwiftUI

// MARK: - Section Divider

/// A styled divider for menu bar sections
struct SectionDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }
}

// MARK: - Section Header

/// A styled section header for menu bar (bold, not uppercase)
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
    }
}

// MARK: - Menu Bar Divider (smaller)

/// A styled divider for menu bar
struct MenuBarDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }
}

// MARK: - Toggle Row

/// A menu bar style toggle with a switch on the right side and hover effect
struct MenuBarToggle: View {
    let name: String
    @Binding var isOn: Bool
    var isDisabled: Bool = false
    @State private var isHovered = false

    var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isDisabled ? .secondary : .primary)
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .tint(.blue)
                .scaleEffect(0.8)
                .disabled(isDisabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(.rect)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered && !isDisabled ? .gray.opacity(0.1) : .clear)
                .padding(.horizontal, 4)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Expandable Picker Row

/// A menu bar style picker that expands inline to show options with hover effect
struct MenuBarExpandablePicker<SelectionValue: Hashable & Equatable>: View {
    let name: String
    @Binding var selection: SelectionValue
    let options: [(value: SelectionValue, label: String)]
    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(currentLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
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

            // Expanded options
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(options, id: \.value) { option in
                        PickerOptionRow(
                            label: option.label,
                            isSelected: selection == option.value
                        ) {
                            selection = option.value
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded = false
                            }
                        }
                    }
                }
                .padding(.leading, 12)
                .background(.quaternary.opacity(0.3))
            }
        }
    }

    private var currentLabel: String {
        options.first { $0.value == selection }?.label ?? ""
    }
}

// MARK: - Picker Option Row

/// A single option row in an expandable picker with hover effect
struct PickerOptionRow: View {
    let label: String
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
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

// MARK: - Device Row (for microphone selection)

/// A device selection row with icon in circle, native macOS style
struct DeviceRow: View {
    let name: String
    let icon: String
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Icon in circle
                ZStack {
                    Circle()
                        .fill(isSelected ? .blue.opacity(0.8) : .gray.opacity(0.3))
                        .frame(width: 24, height: 24)

                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isSelected ? .white : .primary)
                }

                // Name
                Text(name)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)

                Spacer()

                // Checkmark when selected
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.blue)
                }
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

// MARK: - Microphone Expandable Picker

/// A microphone picker with device-style rows (icon in circle)
struct MicrophoneExpandablePicker: View {
    @Binding var selectedID: String?
    let devices: [AudioInputDevice]
    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Microphone")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(currentLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
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

            // Expanded device options
            if isExpanded {
                VStack(spacing: 0) {
                    // System Default option
                    DeviceRow(
                        name: "System Default",
                        icon: "mic",
                        isSelected: selectedID == nil
                    ) {
                        selectedID = nil
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded = false
                        }
                    }

                    // Available devices
                    ForEach(devices) { device in
                        DeviceRow(
                            name: device.name,
                            icon: device.isDefault ? "mic.fill" : "mic",
                            isSelected: selectedID == device.id
                        ) {
                            selectedID = device.id
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded = false
                            }
                        }
                    }
                }
                .padding(.leading, 12)
                .background(.quaternary.opacity(0.3))
            }
        }
    }

    private var currentLabel: String {
        if let id = selectedID, let device = devices.first(where: { $0.id == id }) {
            return device.name
        }
        return "System Default"
    }
}

// MARK: - Expandable Section (for arbitrary content)

/// A menu bar style expandable section with hover effect
struct MenuBarExpandableSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
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

            // Expanded content
            if isExpanded {
                VStack(spacing: 0) {
                    content
                }
                .padding(.leading, 12)
                .background(.quaternary.opacity(0.3))
            }
        }
    }
}

// MARK: - Video Settings Section

/// Video settings section with header and inline content
struct VideoSettingsSection: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Video")

            // Content Filter Section
            MenuBarExpandableSection(title: "Content Filter") {
                MenuBarToggle(name: "Show Cursor", isOn: $settings.showCursor)
                MenuBarToggle(name: "Show Wallpaper", isOn: $settings.showWallpaper)
                MenuBarToggle(name: "Show Menu Bar", isOn: $settings.showMenuBar)
                MenuBarToggle(name: "Show Dock", isOn: $settings.showDock)
                MenuBarToggle(name: "Show Window Shadows", isOn: $settings.showWindowShadows)
            }

            // Frame Rate Picker
            MenuBarExpandablePicker(
                name: "Frame Rate",
                selection: $settings.frameRate,
                options: FrameRate.allCases.map { ($0, $0.displayName) }
            )

            // Video Codec Picker
            MenuBarExpandablePicker(
                name: "Codec",
                selection: $settings.videoCodec,
                options: VideoCodec.allCases.map { ($0, $0.rawValue) }
            )

            // Container Format Picker
            MenuBarExpandablePicker(
                name: "Container",
                selection: $settings.containerFormat,
                options: ContainerFormat.allCases.map { ($0, $0.rawValue.uppercased()) }
            )

            // Alpha Channel Toggle (always visible, but disabled for non-toggleable codecs)
            MenuBarToggle(
                name: "Capture Alpha Channel",
                isOn: $settings.captureAlphaChannel,
                isDisabled: !settings.videoCodec.canToggleAlpha
            )
        }
    }
}

// MARK: - Audio Settings Section

/// Audio settings section with header and inline content
struct AudioSettingsSection: View {
    @Bindable var settings: SettingsStore
    let audioDeviceService: AudioDeviceService

    var body: some View {
        VStack(spacing: 0) {
            // Separator before Audio section
            SectionDivider()

            SectionHeader(title: "Audio")

            // System Audio Toggle
            MenuBarToggle(name: "Capture System Audio", isOn: $settings.captureSystemAudio)

            // Microphone Toggle
            MenuBarToggle(name: "Capture Microphone", isOn: $settings.captureMicrophone)

            // Microphone Source Picker (only shown when microphone is enabled)
            if settings.captureMicrophone {
                MicrophoneExpandablePicker(
                    selectedID: $settings.selectedMicrophoneID,
                    devices: audioDeviceService.availableDevices
                )
            }

            // Audio Codec Picker
            MenuBarExpandablePicker(
                name: "Audio Codec",
                selection: $settings.audioCodec,
                options: AudioCodec.allCases.map { ($0, $0.rawValue) }
            )
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        VideoSettingsSection(settings: SettingsStore())
        AudioSettingsSection(settings: SettingsStore(), audioDeviceService: AudioDeviceService())
    }
    .frame(width: 320)
    .padding(.vertical, 8)
}
