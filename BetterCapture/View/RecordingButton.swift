//
//  RecordingButton.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 29.01.26.
//

import SwiftUI

/// A combined button that shows recording status and allows pausing and stopping
struct RecordingButton: View {
    let duration: String
    let isPaused: Bool
    let pauseAction: () -> Void
    let action: () -> Void
    @State private var isHovered = false
    @State private var isPauseHovered = false

    var body: some View {
        HStack(spacing: 0) {
            Button(
                isPaused ? "Resume recording" : "Pause recording",
                systemImage: isPaused ? "play.fill" : "pause.fill",
                action: pauseAction
            )
            .labelStyle(.iconOnly)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isPaused ? Color.orange : Color.primary)
            .frame(width: 28, height: 28)
            .background(
                isPaused
                    ? Color.orange.opacity(isPauseHovered ? 0.2 : 0.12)
                    : Color.gray.opacity(isPauseHovered ? 0.2 : 0.12),
                in: .circle
            )
            .contentShape(.circle)
            .buttonStyle(.plain)
            .padding(.leading, 12)
            .padding(.trailing, 6)
            .onHover { hovering in
                isPauseHovered = hovering
            }
            .help(isPaused ? "Resume recording" : "Pause recording")

            Button(action: action) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(.gray.opacity(0.2))
                            .frame(width: 24, height: 24)

                        Image(systemName: "stop.circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.red.opacity(0.8))
                    }

                    Text(isPaused ? "Paused" : "Stop Recording")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isPaused ? Color.orange : Color.primary)
                }
                .padding(.leading, 2)
                .padding(.trailing, 12)
                .padding(.vertical, 6)
                .contentShape(.rect)
                .background(
                    isHovered ? Color.red.opacity(0.1) : .clear,
                    in: .rect(cornerRadius: 6)
                )
            }
            .buttonStyle(.plain)
            .help("Stop recording")
            .onHover { hovering in
                isHovered = hovering
            }

            Spacer(minLength: 8)

            Text(duration)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.leading, 12)
                .padding(.trailing, 24)
        }
    }
}
