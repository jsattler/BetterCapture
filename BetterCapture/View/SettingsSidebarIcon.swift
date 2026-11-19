//
//  SettingsSidebarIcon.swift
//  BetterCapture
//

import SwiftUI

/// A white SF Symbol on a colored rounded tile, as used in System Settings
struct SettingsSidebarIcon: View {
    let pane: SettingsPane

    var body: some View {
        Image(systemName: pane.systemImage)
            .font(.caption)
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(pane.tint.gradient, in: .rect(cornerRadius: 5))
    }
}
