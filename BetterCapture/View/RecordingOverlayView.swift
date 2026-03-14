//
//  RecordingOverlayView.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 14.03.26.
//

import SwiftUI

/// The SwiftUI content view hosted inside the recording overlay panel.
/// Shows a live preview and two action buttons: Start Recording and Cancel.
struct RecordingOverlayView: View {
    let viewModel: RecorderViewModel
    let onCancel: () -> Void

    @State private var currentPreview: NSImage?

    var body: some View {
        VStack(spacing: 0) {
            previewArea
            buttonRow
        }
        .padding(10)
        .padding(.top, 4)
        .onChange(of: viewModel.previewService.previewImage) { _, newImage in
            currentPreview = newImage
        }
        .onAppear {
            currentPreview = viewModel.previewService.previewImage
        }
    }

    // MARK: - Preview Area

    private var previewArea: some View {
        ZStack {
            if let image = currentPreview {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.15))
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                    }
            }

            // "LIVE" badge — only shown when preview is streaming
            if viewModel.previewService.isCapturing {
                VStack {
                    HStack {
                        Spacer()
                        Text("LIVE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red, in: .capsule)
                    }
                    Spacer()
                }
                .padding(6)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
    }

    // MARK: - Buttons

    private var buttonRow: some View {
        VStack(spacing: 6) {
            Button("Start Recording", systemImage: "record.circle") {
                Task {
                    await viewModel.startRecordingFromOverlay()
                }
            }
            .buttonStyle(OverlayButtonStyle(labelColor: .green, weight: .semibold))

            Button("Cancel") {
                onCancel()
            }
            .buttonStyle(OverlayButtonStyle(labelColor: .red, weight: .medium))
        }
        .padding(.top, 10)
    }
}

// MARK: - Button Style

private struct OverlayButtonStyle: ButtonStyle {
    let labelColor: Color
    var weight: Font.Weight = .medium

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: weight))
            .foregroundStyle(configuration.isPressed ? labelColor.opacity(0.6) : labelColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(configuration.isPressed ? Color.gray.opacity(0.2) : Color.gray.opacity(0.12))
            )
    }
}
