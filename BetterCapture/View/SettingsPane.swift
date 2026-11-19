//
//  SettingsPane.swift
//  BetterCapture
//

import SwiftUI

/// The panes listed in the settings sidebar
enum SettingsPane: String, CaseIterable, Identifiable {
    case general = "General"
    case video = "Video"
    case audio = "Audio"
    case shortcuts = "Shortcuts"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .general: "gearshape.fill"
        case .video: "video.fill"
        case .audio: "waveform"
        case .shortcuts: "command"
        }
    }

    var tint: Color {
        switch self {
        case .general: .gray
        case .video: .blue
        case .audio: .pink
        case .shortcuts: .indigo
        }
    }
}
