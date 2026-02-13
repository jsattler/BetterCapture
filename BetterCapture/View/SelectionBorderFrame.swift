//
//  SelectionBorderFrame.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 13.02.26.
//

import AppKit

/// A lightweight, click-through panel that draws a dashed border around the
/// selected recording area while a recording is in progress.
@MainActor
final class SelectionBorderFrame {

    private var panel: NSPanel?

    /// Shows the dashed border frame at the given screen-coordinate rect.
    /// - Parameter screenRect: Rectangle in NSScreen coordinates (bottom-left origin)
    func show(screenRect: CGRect) {
        dismiss()

        let panel = NSPanel(
            contentRect: screenRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false

        let borderView = SelectionBorderView(frame: NSRect(origin: .zero, size: screenRect.size))
        panel.contentView = borderView
        panel.orderFront(nil)

        self.panel = panel
    }

    /// Removes the border frame from screen.
    func dismiss() {
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
    }
}

// MARK: - SelectionBorderView

/// Draws only a dashed rectangular border, nothing else.
private final class SelectionBorderView: NSView {

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let insetRect = bounds.insetBy(dx: 2, dy: 2)

        // Black outline underneath for contrast on light backgrounds
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(3)
        context.stroke(insetRect)

        // White dashed stroke on top
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [6, 4])
        context.stroke(insetRect)
    }
}
