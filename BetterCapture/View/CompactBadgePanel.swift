//
//  CompactBadgePanel.swift
//  BetterCapture
//

import AppKit
import Observation
import SwiftUI

// MARK: - Panel

/// A borderless, non-activating, transparent panel hosting the compact badge.
private final class CompactBadgeNSPanel: NSPanel {
    /// Called when the user presses Escape
    var onCancel: (() -> Void)?

    init() {
        super.init(
            contentRect: .zero,
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
        // Keep the badge out of screen recordings
        sharingType = .none
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

// MARK: - Coordinator

/// Runs the compact layout: a menu bar status item and the floating badge.
///
/// The badge starts hidden and behaves like a menu, see ``CompactBadgeVisibility``.
/// While idle it appears at its saved position, while recording below the icon.
@MainActor
final class CompactBadgeCoordinator: NSObject, NSWindowDelegate {

    /// The `UserDefaults` key for the badge's idle position
    private static let originKey = "compactBadgeOrigin"

    private let viewModel: RecorderViewModel
    private var panel: CompactBadgeNSPanel?
    private var statusItem: NSStatusItem?
    private var visibility = CompactBadgeVisibility()
    private var wasRecording = false
    /// The badge's position before it was moved below the status item while recording
    private var idleOrigin: CGPoint?
    /// The panel's last known frame, to keep the badge centered when its width changes
    private var lastFrame: CGRect?
    private var didRequestPermissions = false

    init(viewModel: RecorderViewModel) {
        self.viewModel = viewModel
    }

    /// Starts following the layout mode and recording state.
    func start() {
        observeState()
        observeStatusItemLabel()
    }

    // MARK: - Observation

    private func observeState() {
        let (layoutMode, isRecording) = withObservationTracking {
            (viewModel.settings.layoutMode, viewModel.isRecording)
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeState()
            }
        }

        if isRecording != wasRecording {
            visibility.recordingStateDidChange()
            wasRecording = isRecording
        }

        updateStatusItem(for: layoutMode)
        requestPermissionsIfNeeded(for: layoutMode)
        updatePanel()
    }

    /// The menu bar window isn't used in the compact layout, so request permissions here, once
    private func requestPermissionsIfNeeded(for layoutMode: LayoutMode) {
        guard layoutMode == .compact, !didRequestPermissions else { return }
        didRequestPermissions = true

        Task {
            await viewModel.requestPermissionsOnLaunch()
        }
    }

    private func observeStatusItemLabel() {
        withObservationTracking {
            updateStatusItemLabel()
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeStatusItemLabel()
            }
        }
    }

    // MARK: - Status Item

    private func updateStatusItem(for layoutMode: LayoutMode) {
        switch layoutMode {
        case .compact:
            guard statusItem == nil else { return }
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.target = self
            item.button?.action = #selector(statusItemClicked)
            statusItem = item
            updateStatusItemLabel()
        case .comfortable:
            guard let statusItem else { return }
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    /// Mirrors ``MenuBarLabel``: record icon, timer while recording, orange pause icon while paused
    private func updateStatusItemLabel() {
        // Read the state before the guard, so observation keeps tracking it while no item exists
        let isPaused = viewModel.isPaused
        let isRecording = viewModel.isRecording
        let formattedDuration = viewModel.formattedDuration
        let recordingDuration = viewModel.recordingDuration

        guard let button = statusItem?.button else { return }

        if isPaused {
            let configuration = NSImage.SymbolConfiguration(paletteColors: [.systemOrange])
            button.image = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: "Paused")?
                .withSymbolConfiguration(configuration)
        } else if isRecording {
            button.image = MenuBarTimerImage.make(text: formattedDuration, recordingDuration: recordingDuration)
        } else {
            button.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "BetterCapture")
        }
    }

    @objc private func statusItemClicked() {
        visibility.toggle()
        updatePanel()
    }

    private func hide() {
        visibility.hide()
        updatePanel()
    }

    // MARK: - Panel

    private func updatePanel() {
        let isRecording = viewModel.isRecording
        guard visibility.isVisible(layoutMode: viewModel.settings.layoutMode) else {
            panel?.orderOut(nil)
            return
        }

        let panel = panel ?? makePanel()
        self.panel = panel

        if isRecording {
            moveBelowStatusItem(panel)
        } else {
            if let idleOrigin {
                self.idleOrigin = nil
                panel.setFrameOrigin(idleOrigin)
            }
            moveOnScreenIfNeeded(panel)
        }

        // Key, so Escape reaches the panel. It's non-activating, so the frontmost app stays active
        panel.makeKeyAndOrderFront(nil)
    }

    private func makePanel() -> CompactBadgeNSPanel {
        let panel = CompactBadgeNSPanel()
        panel.onCancel = { [weak self] in
            self?.hide()
        }

        let hostingController = NSHostingController(
            rootView: CompactBadgeView(viewModel: viewModel) { [weak self] in
                self?.hide()
            }
        )
        hostingController.sizingOptions = [.preferredContentSize]
        panel.contentViewController = hostingController
        // Size the panel now, so the default position below centers the actual badge
        panel.setContentSize(hostingController.view.fittingSize)

        let savedOrigin = UserDefaults.standard.string(forKey: Self.originKey).map(NSPointFromString)
        panel.setFrameOrigin(savedOrigin ?? defaultOrigin(for: panel.frame.size))
        lastFrame = panel.frame
        panel.delegate = self

        return panel
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        guard let panel else { return }
        lastFrame = panel.frame

        // Only remember idle positions, not the temporary one below the status item
        guard idleOrigin == nil else { return }
        UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: Self.originKey)
    }

    /// Keeps the badge centered on its previous position when its content changes width
    func windowDidResize(_ notification: Notification) {
        guard let panel, let lastFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(CGPoint(x: lastFrame.midX - size.width / 2, y: lastFrame.maxY - size.height))
        self.lastFrame = panel.frame
    }

    /// Hides the badge when the user clicks elsewhere, like a menu
    func windowDidResignKey(_ notification: Notification) {
        // A click on the status item is handled by its own toggle
        let isClickingStatusItem = NSEvent.pressedMouseButtons != 0
            && statusItem?.button?.window?.frame.contains(NSEvent.mouseLocation) == true
        // Hiding orders the panel out, which resigns key again
        guard !isClickingStatusItem, visibility.isVisible(layoutMode: viewModel.settings.layoutMode) else { return }
        hide()
    }

    /// Brings the badge back if its saved position is no longer on any screen,
    /// for example after a display was disconnected.
    private func moveOnScreenIfNeeded(_ panel: NSPanel) {
        let isOnScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(panel.frame) }
        guard !isOnScreen else { return }
        panel.setFrameOrigin(defaultOrigin(for: panel.frame.size))
    }

    /// Centers the badge below the status item, remembering where it was before.
    private func moveBelowStatusItem(_ panel: NSPanel) {
        guard let buttonFrame = statusItem?.button?.window?.frame,
              let screen = statusItem?.button?.window?.screen else { return }

        if idleOrigin == nil {
            idleOrigin = panel.frame.origin
        }

        let size = panel.frame.size
        let visibleFrame = screen.visibleFrame
        let originX = min(max(buttonFrame.midX - size.width / 2, visibleFrame.minX), visibleFrame.maxX - size.width)
        panel.setFrameOrigin(CGPoint(x: originX, y: buttonFrame.minY - size.height - 4))
    }

    /// Top center of the main screen, just below the menu bar.
    private func defaultOrigin(for size: CGSize) -> CGPoint {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return .zero }
        let frame = screen.visibleFrame
        return CGPoint(x: frame.midX - size.width / 2, y: frame.maxY - size.height - 12)
    }
}
