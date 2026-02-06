//
//  SettingsView.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 29.01.26.
//

import SwiftUI

/// The settings window for BetterCapture
struct SettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        TabView {
            Tab("Video", systemImage: "video") {
                VideoSettingsView(settings: settings)
            }

            Tab("Audio", systemImage: "waveform") {
                AudioSettingsView(settings: settings)
            }

            Tab("Content", systemImage: "rectangle.dashed") {
                ContentFilterSettingsView(settings: settings)
            }
        }
        .frame(width: 450, height: 300)
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
                        Text(codec.rawValue).tag(codec)
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
                    .disabled(!settings.videoCodec.canToggleAlpha)
                    .help(alphaChannelHelpText)
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
                        Text(codec.rawValue).tag(codec)
                    }
                }
                .help("AAC is compressed, PCM is uncompressed lossless")
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

// MARK: - Content Filter Settings

struct ContentFilterSettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Form {
            Section("Display Elements") {
                Toggle("Show Cursor", isOn: $settings.showCursor)
                Toggle("Show Wallpaper", isOn: $settings.showWallpaper)
                Toggle("Show Menu Bar", isOn: $settings.showMenuBar)
                Toggle("Show Dock", isOn: $settings.showDock)
            }

            Section("Window Capture") {
                Toggle("Show Window Shadows", isOn: $settings.showWindowShadows)
                    .help("Include window shadows when capturing individual windows")
            }

            Section {
                HStack {
                    Image(systemName: "folder")
                    Text("Output: ~/Movies/BetterCapture/")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Output Location")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Preview

#Preview {
    SettingsView(settings: SettingsStore())
}
