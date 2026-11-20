//
//  SettingsView.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 29.01.26.
//

import AppKit
import KeyboardShortcuts
import SwiftUI

/// The settings window for BetterCapture
struct SettingsView: View {
    static let windowID = "settings"

    @Bindable var settings: SettingsStore
    var updaterService: UpdaterService
    let audioDeviceService: AudioDeviceService
    let cameraDeviceService: CameraDeviceService
    let permissionService: PermissionService

    @State private var navigation = SettingsNavigation()

    var body: some View {
        NavigationSplitView {
            // Plain buttons instead of List selection, so the active item gets a
            // subtle gray highlight rather than the accent-colored selection
            List(SettingsPane.allCases) { pane in
                Button {
                    navigation.visit(pane)
                } label: {
                    Label {
                        Text(pane.rawValue)
                            .bold(pane == navigation.current)
                    } icon: {
                        SettingsSidebarIcon(pane: pane)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 6)
                    .background(
                        .fill.secondary.opacity(pane == navigation.current ? 1 : 0),
                        in: .rect(cornerRadius: 8)
                    )
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                // The highlight spans the full row, so drop the default insets
                .listRowInsets(EdgeInsets())
            }
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(220)
        } detail: {
            Group {
                switch navigation.current {
                case .general:
                    GeneralSettingsView(settings: settings, updaterService: updaterService)
                case .video:
                    VideoSettingsView(
                        settings: settings,
                        cameraDeviceService: cameraDeviceService,
                        permissionService: permissionService
                    )
                case .audio:
                    AudioSettingsView(settings: settings, audioDeviceService: audioDeviceService)
                case .shortcuts:
                    ShortcutsSettingsView()
                case .commandLine:
                    CommandLineSettingsView(settings: settings)
                }
            }
            .navigationTitle(navigation.current.rawValue)
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button("Back", systemImage: "chevron.left") {
                        navigation.goBack()
                    }
                    .disabled(!navigation.canGoBack)

                    Button("Forward", systemImage: "chevron.right") {
                        navigation.goForward()
                    }
                    .disabled(!navigation.canGoForward)
                }
            }
        }
        .frame(width: 720, height: 520)
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section("Recording") {
                KeyboardShortcuts.Recorder("Toggle Recording", name: .toggleRecording)
                KeyboardShortcuts.Recorder("Pause / Resume Recording", name: .togglePause)
            }

            Section {
                KeyboardShortcuts.Recorder("Select Content", name: .selectContent)
                KeyboardShortcuts.Recorder("Select Area", name: .selectArea)
            } header: {
                Text("Content Selection")
            } footer: {
                SettingsFooter("Shortcuts work globally, even when BetterCapture is not focused.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Video Settings

struct VideoSettingsView: View {
    @Bindable var settings: SettingsStore
    let cameraDeviceService: CameraDeviceService
    let permissionService: PermissionService

    private var alphaChannelHelpText: String {
        switch settings.videoCodec {
        case .proRes4444:
            return "ProRes 4444 always includes alpha channel support"
        case .hevc:
            return "Enable transparency support for HEVC"
        case .h264, .proRes422:
            return "Alpha channel not supported by this codec"
        }
    }

    private var hdrHelpText: String {
        if settings.videoCodec.supportsHDR {
            return "Enable 10-bit HDR capture for high dynamic range content"
        } else {
            return "HDR is only supported with ProRes 422 and ProRes 4444 codecs"
        }
    }

    private var qualityHelpText: String {
        if settings.videoCodec.supportsQualitySetting {
            return "Controls the video bitrate. Higher quality produces sharper output with larger files"
        } else {
            return "ProRes codecs use fixed-quality encoding"
        }
    }

    private let captureNativeResHelpText = """
        When enabled, captures at the display's native pixel resolution. \
        When disabled, captures at the logical (1x) resolution. Has no effect on non-Retina displays
        """

    var body: some View {
        Form {
            Section("Recording") {
                Picker("Frame Rate", selection: $settings.frameRate) {
                    ForEach(FrameRate.allCases) { rate in
                        Text(rate.displayName).tag(rate)
                    }
                }

                Picker("Codec", selection: $settings.videoCodec) {
                    ForEach(VideoCodec.allCases) { codec in
                        let isSupported = settings.containerFormat.supportedVideoCodecs.contains(codec)
                        if isSupported {
                            Text(codec.rawValue).tag(codec)
                        } else {
                            Text("\(codec.rawValue) (not supported for \(settings.containerFormat.rawValue.uppercased()))")
                                .foregroundStyle(.secondary)
                                .tag(codec)
                        }
                    }
                }

                Picker("Container", selection: $settings.containerFormat) {
                    ForEach(ContainerFormat.allCases) { format in
                        Text(".\(format.rawValue)").tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()

                Picker("Quality", selection: $settings.videoQuality) {
                    ForEach(VideoQuality.allCases) { quality in
                        Text(quality.rawValue).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .disabled(!settings.videoCodec.supportsQualitySetting)
                .help(qualityHelpText)
            }

            Section("Advanced") {
                Toggle("Capture Alpha Channel", isOn: $settings.captureAlphaChannel)
                    .disabled(!settings.videoCodec.canToggleAlpha || !settings.containerFormat.supportsAlphaChannel)
                    .help(alphaChannelHelpText)

                Toggle("HDR Recording", isOn: $settings.captureHDR)
                    .disabled(!settings.videoCodec.supportsHDR)
                    .help(hdrHelpText)

                Toggle("Native Resolution", isOn: $settings.captureNativeResolution)
                    .help(captureNativeResHelpText)
            }

            Section("Camera") {
                Toggle("Presenter Overlay", isOn: $settings.presenterOverlayEnabled)
                    .help("Composite the camera into the recording")

                if settings.presenterOverlayEnabled {
                    Picker("Camera", selection: $settings.selectedCameraID) {
                        Text("System Default").tag(String?.none)
                        ForEach(cameraDeviceService.availableDevices) { device in
                            Text(device.name).tag(Optional(device.id))
                        }
                    }
                }
            }
            .onChange(of: settings.presenterOverlayEnabled) { _, isEnabled in
                // Ask up front rather than letting the first recording fail on a denied camera
                guard isEnabled else { return }

                Task {
                    await permissionService.requestCameraPermission()
                }
            }

            Section("Display Elements") {
                Toggle("Show Cursor", isOn: $settings.showCursor)
                Toggle("Show Wallpaper", isOn: $settings.showWallpaper)
                Toggle("Show Menu Bar", isOn: $settings.showMenuBar)
                Toggle("Show Dock", isOn: $settings.showDock)
                Toggle("Show BetterCapture", isOn: $settings.showBetterCapture)
            }

            Section("Window Capture") {
                Toggle("Show Window Shadows", isOn: $settings.showWindowShadows)
                    .help("Include window shadows when capturing individual windows")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Audio Settings

struct AudioSettingsView: View {
    @Bindable var settings: SettingsStore
    let audioDeviceService: AudioDeviceService

    var body: some View {
        Form {
            Section("Sources") {
                Toggle("Capture System Audio", isOn: $settings.captureSystemAudio)
                    .help("Record audio from applications and system sounds")

                Toggle("Capture Microphone", isOn: $settings.captureMicrophone)
                    .help("Record audio from the selected microphone input")

                if settings.captureMicrophone {
                    Picker("Microphone", selection: $settings.selectedMicrophoneID) {
                        Text("System Default").tag(String?.none)
                        ForEach(audioDeviceService.availableDevices) { device in
                            Text(device.name).tag(Optional(device.id))
                        }
                    }
                }
            }

            Section {
                Picker("Codec", selection: $settings.audioCodec) {
                    ForEach(AudioCodec.allCases) { codec in
                        let isSupported = settings.containerFormat.supportedAudioCodecs.contains(codec)
                        if isSupported {
                            Text(codec.rawValue).tag(codec)
                        } else {
                            Text("\(codec.rawValue) (not supported for \(settings.containerFormat.rawValue.uppercased()))")
                                .foregroundStyle(.secondary)
                                .tag(codec)
                        }
                    }
                }
                .help("AAC is compressed, PCM is uncompressed lossless (MOV only)")
            } header: {
                Text("Format")
            } footer: {
                SettingsFooter("Audio tracks are recorded separately for post-processing flexibility.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Bindable var settings: SettingsStore
    @Bindable var updaterService: UpdaterService

    /// Formats the output directory path for display
    private var displayPath: String {
        let path = settings.outputDirectory.path(percentEncoded: false)
        // Replace home directory with ~ for cleaner display
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    var body: some View {
        Form {
            Section {
                Picker("Layout", selection: $settings.layoutMode) {
                    ForEach(LayoutMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Appearance")
            } footer: {
                SettingsFooter("Compact replaces the menu bar window with a floating badge that appears when you click the menu bar icon.")
            }

            Section("Output Location") {
                LabeledContent {
                    HStack {
                        Button("Change...") {
                            selectOutputDirectory()
                        }

                        if settings.hasCustomOutputDirectory {
                            Button("Reset", role: .destructive) {
                                settings.resetOutputDirectory()
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text(displayPath)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }

            Section("Software Updates") {
                Toggle("Automatically check for updates", isOn: $updaterService.automaticallyChecksForUpdates)

                LabeledContent("Updates") {
                    Button("Check for Update") {
                        updaterService.checkForUpdates()
                    }
                    .disabled(!updaterService.canCheckForUpdates)
                }
            }

            AboutSection()
        }
        .formStyle(.grouped)
    }

    /// Opens an NSOpenPanel to select a custom output directory
    private func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Select Output Directory"
        panel.message = "Choose where recordings will be saved"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = settings.outputDirectory

        if panel.runModal() == .OK, let url = panel.url {
            settings.setCustomOutputDirectory(url)
        }
    }
}

// MARK: - About Section

struct AboutSection: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var gitSHA: String {
        Bundle.main.infoDictionary?["GitSHA"] as? String ?? "dev"
    }

    var body: some View {
        Section("About") {
            LabeledContent("Version", value: "v\(appVersion) (\(gitSHA))")

            LabeledContent("Website") {
                Link("jsattler.github.io/BetterCapture", destination: URL(string: "https://jsattler.github.io/BetterCapture")!)
            }

            LabeledContent("Source Code") {
                Link("github.com/jsattler/BetterCapture", destination: URL(string: "https://github.com/jsattler/BetterCapture")!)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView(
        settings: SettingsStore(),
        updaterService: UpdaterService(),
        audioDeviceService: AudioDeviceService(),
        cameraDeviceService: CameraDeviceService(),
        permissionService: PermissionService()
    )
}
