//
//  RecordingOverlayPanel.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 14.03.26.
//

import AppKit
import SwiftUI

// MARK: - Panel

/// A borderless, non-activating floating panel for the recording overlay.
/// Uses an NSVisualEffectView background with .menu material for the native
/// translucent menu-style appearance.
private final class RecordingOverlayNSPanel: NSPanel {
    init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }
}

// MARK: - Coordinator

/// Manages the lifecycle of the recording overlay panel.
@MainActor
final class RecordingOverlayCoordinator {

    private var panel: RecordingOverlayNSPanel?
    private weak var viewModel: RecorderViewModel?

    // MARK: - Public API

    /// Shows the recording overlay anchored below the menu bar status item on the given screen.
    /// If `screen` is nil the overlay falls back to the screen containing the status item.
    /// Starts the live preview automatically.
    func show(viewModel: RecorderViewModel, screen: NSScreen? = nil) {
        // If already showing, just bring to front
        if let existing = panel {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        self.viewModel = viewModel

        let panelWidth: CGFloat = 280
        let panelHeight: CGFloat = 270

        let origin = overlayOrigin(width: panelWidth, height: panelHeight, preferredScreen: screen)
        let contentRect = CGRect(x: origin.x, y: origin.y, width: panelWidth, height: panelHeight)

        let newPanel = RecordingOverlayNSPanel(contentRect: contentRect)

        // NSVisualEffectView provides the .menu material blur background
        let visualEffect = NSVisualEffectView(frame: .init(origin: .zero, size: contentRect.size))
        visualEffect.material = .menu
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true

        let hostingView = NSHostingView(rootView: RecordingOverlayView(viewModel: viewModel) {
            self.dismiss()
        })
        hostingView.frame = visualEffect.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear

        visualEffect.addSubview(hostingView)
        newPanel.contentView = visualEffect

        newPanel.makeKeyAndOrderFront(nil)
        panel = newPanel

        // Auto-start live preview
        Task {
            await viewModel.startPreview()
        }
    }

    /// Dismisses the overlay and stops the live preview.
    func dismiss() {
        guard let panel else { return }
        panel.orderOut(nil)
        self.panel = nil

        if let viewModel {
            Task {
                await viewModel.stopPreview()
            }
        }
        viewModel = nil
    }

    // MARK: - Positioning

    /// Determines the screen-coordinate origin (bottom-left) for the panel.
    ///
    /// Priority:
    /// 1. If a `preferredScreen` is supplied, anchor below that screen's menu bar status item
    ///    (found via the NSStatusBarWindow heuristic restricted to that screen), or fall back
    ///    to the top-right corner of that screen.
    /// 2. Otherwise fall back to the screen containing the status item window, or main screen.
    private func overlayOrigin(width: CGFloat, height: CGFloat, preferredScreen: NSScreen?) -> CGPoint {
        let gap: CGFloat = 4
        let menuBarThickness = NSStatusBar.system.thickness

        // Try to find the NSStatusBarWindow on the preferred screen (or any screen as fallback).
        // The MenuBarExtra(.window) style creates an NSStatusBarWindow whose frame sits in the
        // menu bar area; its class name contains "StatusBar".
        let targetScreen = preferredScreen ?? NSScreen.main ?? NSScreen.screens[0]

        if let statusWindow = NSApp.windows.first(where: {
            String(describing: type(of: $0)).contains("StatusBar") &&
            targetScreen.frame.contains($0.frame.origin)
        }) {
            let frame = statusWindow.frame
            let originX = max(targetScreen.frame.minX, min(frame.midX - width / 2, targetScreen.frame.maxX - width))
            let originY = frame.minY - height - gap
            return CGPoint(x: originX, y: originY)
        }

        // Fallback: top-right corner of the target screen, just below the menu bar.
        let originX = targetScreen.frame.maxX - width - 16
        let originY = targetScreen.frame.maxY - menuBarThickness - height - gap
        return CGPoint(x: originX, y: originY)
    }
}
