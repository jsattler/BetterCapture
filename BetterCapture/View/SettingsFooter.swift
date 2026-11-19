//
//  SettingsFooter.swift
//  BetterCapture
//

import SwiftUI

/// A settings section footer with a leading info icon
struct SettingsFooter: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Label(text, systemImage: "info.circle")
            .font(.callout)
            .foregroundStyle(.secondary)
    }
}
