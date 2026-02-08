//
//  SettingsView.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 29.01.26.
//

import AppKit
import SwiftUI

/// The settings window for BetterCapture
struct SettingsView: View {
    @Bindable var settings: SettingsStore
    var updaterService: UpdaterService

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsView(settings: settings, updaterService: updaterService)
            }

            Tab("Video", systemImage: "video") {
                VideoSettingsView(settings: settings)
            }

            Tab("Audio", systemImage: "waveform") {
                AudioSettingsView(settings: settings)
            }
        }
        .frame(width: 500, height: 420)
    }
}

// MARK: - Video Settings

struct VideoSettingsView: View {
    @Bindable var settings: SettingsStore

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
            }

            Section("Advanced") {
                Toggle("Capture Alpha Channel", isOn: $settings.captureAlphaChannel)
                    .disabled(!settings.videoCodec.canToggleAlpha || !settings.containerFormat.supportsAlphaChannel)
                    .help(alphaChannelHelpText)

                Toggle("HDR Recording", isOn: $settings.captureHDR)
                    .disabled(!settings.videoCodec.supportsHDR)
                    .help(hdrHelpText)
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
        .padding()
    }
}

// MARK: - Audio Settings

struct AudioSettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Form {
            Section("Sources") {
                Toggle("Capture System Audio", isOn: $settings.captureSystemAudio)
                    .help("Record audio from applications and system sounds")

                Toggle("Capture Microphone", isOn: $settings.captureMicrophone)
                    .help("Record audio from the default microphone input")
            }

            Section("Format") {
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
            }

            Section {
                Text("Audio tracks are recorded separately for post-processing flexibility.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Bindable var settings: SettingsStore
    var updaterService: UpdaterService

    @State private var automaticallyChecksForUpdates: Bool

    init(settings: SettingsStore, updaterService: UpdaterService) {
        self.settings = settings
        self.updaterService = updaterService
        self._automaticallyChecksForUpdates = State(initialValue: updaterService.automaticallyChecksForUpdates)
    }

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
                Toggle("Automatically check for updates", isOn: $automaticallyChecksForUpdates)
                    .onChange(of: automaticallyChecksForUpdates) { _, newValue in
                        updaterService.automaticallyChecksForUpdates = newValue
                    }

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
        .padding()
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
    SettingsView(settings: SettingsStore(), updaterService: UpdaterService())
}
