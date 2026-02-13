//
//  AreaSelectionOverlay.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 11.02.26.
//

import AppKit
import OSLog

/// Result of an area selection operation
struct AreaSelectionResult: Sendable {
    /// The selected rectangle in screen points (NSScreen coordinate space, origin bottom-left)
    let screenRect: CGRect
    /// The NSScreen on which the selection was made
    let screen: NSScreen
}

// MARK: - AreaSelectionPanel

/// A borderless, transparent panel that covers a display for rectangle drawing
final class AreaSelectionPanel: NSPanel {

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - AreaSelectionOverlay

/// Manages the area selection overlay for drawing a capture rectangle on screen
@MainActor
final class AreaSelectionOverlay {

    // MARK: - Properties

    private var panels: [AreaSelectionPanel] = []
    private var overlayViews: [AreaSelectionView] = []
    private var continuation: CheckedContinuation<AreaSelectionResult?, Never>?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture",
        category: "AreaSelectionOverlay"
    )

    // MARK: - Public Methods

    /// Presents the area selection overlay on all connected displays
    /// - Returns: The selected area result, or nil if cancelled
    func present() async -> AreaSelectionResult? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            logger.error("No screens available")
            return nil
        }

        logger.info("Presenting area selection on \(screens.count) screen(s)")

        return await withCheckedContinuation { continuation in
            self.continuation = continuation

            for screen in screens {
                let panel = AreaSelectionPanel(screen: screen)

                let overlayView = AreaSelectionView(
                    frame: NSRect(origin: .zero, size: screen.frame.size),
                    screen: screen
                )
                overlayView.delegate = self

                panel.contentView = overlayView
                panel.makeKeyAndOrderFront(nil)

                panels.append(panel)
                overlayViews.append(overlayView)
            }

            // Ensure the panels capture all events
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Private Methods

    private func dismiss() {
        for panel in panels {
            panel.orderOut(nil)
            panel.close()
        }
        panels.removeAll()
        overlayViews.removeAll()
        NSCursor.arrow.set()
    }

    /// Clears the selection on all overlay views except the given one
    private func clearOtherViews(except activeView: AreaSelectionView) {
        for view in overlayViews where view !== activeView {
            view.resetSelection()
        }
    }
}

// MARK: - AreaSelectionViewDelegate

extension AreaSelectionOverlay: AreaSelectionViewDelegate {

    func areaSelectionView(_ view: AreaSelectionView, didConfirmSelection rect: CGRect, on screen: NSScreen) {
        logger.info("Area selected: \(rect.origin.x),\(rect.origin.y) \(rect.width)x\(rect.height)")

        let result = AreaSelectionResult(screenRect: rect, screen: screen)
        dismiss()
        continuation?.resume(returning: result)
        continuation = nil
    }

    func areaSelectionViewDidCancel(_ view: AreaSelectionView) {
        logger.info("Area selection cancelled")
        dismiss()
        continuation?.resume(returning: nil)
        continuation = nil
    }

    func areaSelectionViewDidBeginDrawing(_ view: AreaSelectionView) {
        clearOtherViews(except: view)
    }
}

// MARK: - AreaSelectionViewDelegate Protocol

@MainActor
protocol AreaSelectionViewDelegate: AnyObject {
    func areaSelectionView(_ view: AreaSelectionView, didConfirmSelection rect: CGRect, on screen: NSScreen)
    func areaSelectionViewDidCancel(_ view: AreaSelectionView)
    func areaSelectionViewDidBeginDrawing(_ view: AreaSelectionView)
}

// MARK: - Interaction State

private enum InteractionState {
    case idle
    case drawing(origin: CGPoint)
    case adjusting
    case moving(offset: CGPoint)
    case resizing(handle: ResizeHandle)
}

private enum ResizeHandle {
    case topLeft, top, topRight
    case left, right
    case bottomLeft, bottom, bottomRight
}

// MARK: - AreaSelectionView

/// The NSView that handles drawing the overlay, selection rectangle, and user interaction
@MainActor
final class AreaSelectionView: NSView {

    // MARK: - Properties

    weak var delegate: AreaSelectionViewDelegate?

    private let screen: NSScreen
    private var selectionRect: CGRect = .zero
    private var interactionState: InteractionState = .idle
    private var trackingArea: NSTrackingArea?

    /// Whether the dimmed overlay should be shown (only after user starts drawing)
    private var showOverlay = false

    /// Minimum selection size in points
    private let minimumSize: CGFloat = 24

    /// Size of resize handles in points
    private let handleSize: CGFloat = 8

    /// Margin around handles for hit testing
    private let handleHitMargin: CGFloat = 8

    /// Overlay dimming opacity
    private let dimmingOpacity: CGFloat = 0.5

    /// Confirm and cancel buttons shown during adjusting state
    private var confirmButton: NSButton?
    private var cancelButton: NSButton?
    private var buttonContainer: NSView?

    // MARK: - Initialization

    init(frame: NSRect, screen: NSScreen) {
        self.screen = screen
        super.init(frame: frame)
        setupTrackingArea()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods

    /// Resets the selection, called by the overlay coordinator to clear other screens
    func resetSelection() {
        selectionRect = .zero
        interactionState = .idle
        showOverlay = false
        hideActionButtons()
        needsDisplay = true
    }

    // MARK: - View Lifecycle

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        setupTrackingArea()
    }

    private func setupTrackingArea() {
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    // MARK: - Key Events

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // Escape
            delegate?.areaSelectionViewDidCancel(self)
        case 36, 76: // Enter / Return
            confirmSelectionIfValid()
        default:
            super.keyDown(with: event)
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        // Ensure this panel becomes key so keyboard events route here
        window?.makeKey()

        let point = convert(event.locationInWindow, from: nil)

        // Double-click inside selection to confirm
        if event.clickCount == 2, case .adjusting = interactionState, selectionRect.contains(point) {
            confirmSelectionIfValid()
            return
        }

        switch interactionState {
        case .adjusting:
            // Check if clicking on a resize handle first (highest priority)
            if let handle = resizeHandle(at: point) {
                hideActionButtons()
                interactionState = .resizing(handle: handle)
            }
            // Check if clicking inside the selection (to move it)
            else if selectionRect.contains(point) {
                hideActionButtons()
                let offset = CGPoint(
                    x: point.x - selectionRect.origin.x,
                    y: point.y - selectionRect.origin.y
                )
                interactionState = .moving(offset: offset)
            }
            // Clicking outside the selection starts a new one
            else {
                hideActionButtons()
                beginDrawing(at: point)
            }

        case .idle:
            beginDrawing(at: point)

        default:
            break
        }

        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let clampedPoint = clampToView(point)

        switch interactionState {
        case .drawing(let origin):
            selectionRect = rectFrom(origin, to: clampedPoint)

        case .moving(let offset):
            var newOrigin = CGPoint(
                x: clampedPoint.x - offset.x,
                y: clampedPoint.y - offset.y
            )
            // Clamp to view bounds
            newOrigin.x = max(0, min(newOrigin.x, bounds.width - selectionRect.width))
            newOrigin.y = max(0, min(newOrigin.y, bounds.height - selectionRect.height))
            selectionRect.origin = newOrigin

        case .resizing(let handle):
            applyResize(handle: handle, to: clampedPoint)

        default:
            break
        }

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        switch interactionState {
        case .drawing:
            if selectionRect.width >= minimumSize && selectionRect.height >= minimumSize {
                interactionState = .adjusting
                showActionButtons()
            } else {
                // Selection too small, reset
                selectionRect = .zero
                interactionState = .idle
                showOverlay = false
            }

        case .moving:
            interactionState = .adjusting
            showActionButtons()

        case .resizing:
            enforceMinimumSize()
            interactionState = .adjusting
            showActionButtons()

        default:
            break
        }

        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        updateCursor(at: point)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Only draw the dimmed overlay after the user starts drawing
        guard showOverlay else { return }

        // Draw dimmed overlay
        context.setFillColor(NSColor.black.withAlphaComponent(dimmingOpacity).cgColor)
        context.fill(bounds)

        guard selectionRect.width > 0 && selectionRect.height > 0 else { return }

        // Clear the selection area (make it transparent to show the screen content)
        context.setBlendMode(.clear)
        context.fill(selectionRect)
        context.setBlendMode(.normal)

        // Draw dashed selection border
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [6, 4])
        context.stroke(selectionRect)

        // Reset dash pattern for other drawing
        context.setLineDash(phase: 0, lengths: [])

        // Draw resize handles if adjusting
        if case .adjusting = interactionState {
            drawResizeHandles(in: context)
            drawDimensionLabel(in: context)
        }

        // Draw dimension label while drawing
        if case .drawing = interactionState {
            drawDimensionLabel(in: context)
        }
    }

    private func drawResizeHandles(in context: CGContext) {
        let handles = allHandleRects()
        context.setFillColor(NSColor.white.cgColor)
        context.setStrokeColor(NSColor.gray.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(0.5)

        for rect in handles.values {
            let path = CGPath(ellipseIn: rect, transform: nil)
            context.addPath(path)
            context.drawPath(using: .fillStroke)
        }
    }

    private func drawDimensionLabel(in context: CGContext) {
        let scale = screen.backingScaleFactor
        let pixelWidth = selectionRect.width * scale
        let pixelHeight = selectionRect.height * scale

        // Snap to even pixel counts (matches the formula used by RecorderViewModel)
        let evenWidth = Int(ceil(pixelWidth / 2) * 2)
        let evenHeight = Int(ceil(pixelHeight / 2) * 2)

        let text = "\(evenWidth) x \(evenHeight)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()

        let padding: CGFloat = 6
        let backgroundRect = CGRect(
            x: selectionRect.midX - (size.width + padding * 2) / 2,
            y: selectionRect.minY - size.height - padding * 2 - 8,
            width: size.width + padding * 2,
            height: size.height + padding * 2
        )

        // Ensure label stays within view bounds
        var adjustedRect = backgroundRect
        if adjustedRect.minY < 0 {
            adjustedRect.origin.y = selectionRect.maxY + 8
        }
        adjustedRect.origin.x = max(4, min(adjustedRect.origin.x, bounds.width - adjustedRect.width - 4))

        // Draw background
        context.setFillColor(NSColor.black.withAlphaComponent(0.7).cgColor)
        let bgPath = CGPath(roundedRect: adjustedRect, cornerWidth: 4, cornerHeight: 4, transform: nil)
        context.addPath(bgPath)
        context.fillPath()

        // Draw text
        let textPoint = CGPoint(
            x: adjustedRect.origin.x + padding,
            y: adjustedRect.origin.y + padding
        )
        attributedString.draw(at: textPoint)
    }

    // MARK: - Action Buttons

    private func showActionButtons() {
        guard buttonContainer == nil else {
            updateButtonPositions()
            return
        }

        let container = NSView()

        let confirm = makeActionButton(
            title: "Confirm",
            color: .systemBlue,
            action: #selector(confirmButtonClicked)
        )

        let cancel = makeActionButton(
            title: "Cancel",
            color: .systemRed,
            action: #selector(cancelButtonClicked)
        )

        container.addSubview(confirm)
        container.addSubview(cancel)
        addSubview(container)

        confirm.translatesAutoresizingMaskIntoConstraints = false
        cancel.translatesAutoresizingMaskIntoConstraints = false
        container.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            confirm.topAnchor.constraint(equalTo: container.topAnchor),
            confirm.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            confirm.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            cancel.topAnchor.constraint(equalTo: container.topAnchor),
            cancel.leadingAnchor.constraint(equalTo: confirm.trailingAnchor, constant: 12),
            cancel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            cancel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        self.confirmButton = confirm
        self.cancelButton = cancel
        self.buttonContainer = container

        updateButtonPositions()
    }

    private func hideActionButtons() {
        buttonContainer?.removeFromSuperview()
        buttonContainer = nil
        confirmButton = nil
        cancelButton = nil
    }

    private func updateButtonPositions() {
        guard let container = buttonContainer else { return }

        // Let auto layout calculate the intrinsic size, then position manually
        container.layoutSubtreeIfNeeded()
        let fittingSize = container.fittingSize

        container.frame = CGRect(
            x: selectionRect.midX - fittingSize.width / 2,
            y: selectionRect.midY - fittingSize.height / 2,
            width: fittingSize.width,
            height: fittingSize.height
        )
    }

    private func makeActionButton(title: String, color: NSColor, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = color.withAlphaComponent(0.7).cgColor
        button.layer?.cornerRadius = 18
        button.contentTintColor = .white
        button.font = .systemFont(ofSize: 14, weight: .medium)
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        button.heightAnchor.constraint(equalToConstant: 36).isActive = true
        return button
    }

    @objc private func confirmButtonClicked() {
        confirmSelectionIfValid()
    }

    @objc private func cancelButtonClicked() {
        delegate?.areaSelectionViewDidCancel(self)
    }

    // MARK: - Handle Calculation

    private func allHandleRects() -> [ResizeHandle: CGRect] {
        let r = selectionRect
        let s = handleSize
        let half = s / 2

        return [
            .topLeft: CGRect(x: r.minX - half, y: r.maxY - half, width: s, height: s),
            .top: CGRect(x: r.midX - half, y: r.maxY - half, width: s, height: s),
            .topRight: CGRect(x: r.maxX - half, y: r.maxY - half, width: s, height: s),
            .left: CGRect(x: r.minX - half, y: r.midY - half, width: s, height: s),
            .right: CGRect(x: r.maxX - half, y: r.midY - half, width: s, height: s),
            .bottomLeft: CGRect(x: r.minX - half, y: r.minY - half, width: s, height: s),
            .bottom: CGRect(x: r.midX - half, y: r.minY - half, width: s, height: s),
            .bottomRight: CGRect(x: r.maxX - half, y: r.minY - half, width: s, height: s),
        ]
    }

    /// Hit-tests resize handles with priority for corners over edges
    private func resizeHandle(at point: CGPoint) -> ResizeHandle? {
        let handles = allHandleRects()

        // Check corners first (they should have priority over edges)
        let corners: [ResizeHandle] = [.topLeft, .topRight, .bottomLeft, .bottomRight]
        for handle in corners {
            if let rect = handles[handle] {
                let hitRect = rect.insetBy(dx: -handleHitMargin, dy: -handleHitMargin)
                if hitRect.contains(point) {
                    return handle
                }
            }
        }

        // Then check edges
        let edges: [ResizeHandle] = [.top, .bottom, .left, .right]
        for handle in edges {
            if let rect = handles[handle] {
                let hitRect = rect.insetBy(dx: -handleHitMargin, dy: -handleHitMargin)
                if hitRect.contains(point) {
                    return handle
                }
            }
        }

        return nil
    }

    // MARK: - Drawing Start

    /// Begins a new drawing operation, notifying the delegate to clear other screens
    private func beginDrawing(at point: CGPoint) {
        interactionState = .drawing(origin: point)
        selectionRect = .zero
        showOverlay = true
        delegate?.areaSelectionViewDidBeginDrawing(self)
    }

    // MARK: - Resize Logic

    /// Applies resize for a given handle, constraining axis movement for edge handles
    private func applyResize(handle: ResizeHandle, to point: CGPoint) {
        var newRect = selectionRect

        switch handle {
        // Corner handles: free resize from the opposite corner
        case .topLeft:
            newRect = rectFrom(CGPoint(x: selectionRect.maxX, y: selectionRect.minY), to: point)
        case .topRight:
            newRect = rectFrom(CGPoint(x: selectionRect.minX, y: selectionRect.minY), to: point)
        case .bottomLeft:
            newRect = rectFrom(CGPoint(x: selectionRect.maxX, y: selectionRect.maxY), to: point)
        case .bottomRight:
            newRect = rectFrom(CGPoint(x: selectionRect.minX, y: selectionRect.maxY), to: point)

        // Edge handles: only move the affected edge, keep perpendicular axis fixed
        case .top:
            let newMaxY = max(selectionRect.minY + minimumSize, point.y)
            newRect = CGRect(
                x: selectionRect.minX,
                y: selectionRect.minY,
                width: selectionRect.width,
                height: newMaxY - selectionRect.minY
            )
        case .bottom:
            let newMinY = min(selectionRect.maxY - minimumSize, point.y)
            newRect = CGRect(
                x: selectionRect.minX,
                y: newMinY,
                width: selectionRect.width,
                height: selectionRect.maxY - newMinY
            )
        case .left:
            let newMinX = min(selectionRect.maxX - minimumSize, point.x)
            newRect = CGRect(
                x: newMinX,
                y: selectionRect.minY,
                width: selectionRect.maxX - newMinX,
                height: selectionRect.height
            )
        case .right:
            let newMaxX = max(selectionRect.minX + minimumSize, point.x)
            newRect = CGRect(
                x: selectionRect.minX,
                y: selectionRect.minY,
                width: newMaxX - selectionRect.minX,
                height: selectionRect.height
            )
        }

        selectionRect = newRect
    }

    // MARK: - Cursor Management

    private func updateCursor(at point: CGPoint) {
        guard case .adjusting = interactionState else {
            NSCursor.crosshair.set()
            return
        }

        if let container = buttonContainer, container.frame.contains(point) {
            NSCursor.arrow.set()
        } else if let handle = resizeHandle(at: point) {
            cursorForHandle(handle).set()
        } else if selectionRect.contains(point) {
            NSCursor.openHand.set()
        } else {
            NSCursor.crosshair.set()
        }
    }

    /// Returns the native macOS frame resize cursor for a given handle position
    private func cursorForHandle(_ handle: ResizeHandle) -> NSCursor {
        let directions: NSCursor.FrameResizeDirection.Set = [.inward, .outward]

        switch handle {
        case .topLeft:
            return .frameResize(position: .topLeft, directions: directions)
        case .top:
            return .frameResize(position: .top, directions: directions)
        case .topRight:
            return .frameResize(position: .topRight, directions: directions)
        case .left:
            return .frameResize(position: .left, directions: directions)
        case .right:
            return .frameResize(position: .right, directions: directions)
        case .bottomLeft:
            return .frameResize(position: .bottomLeft, directions: directions)
        case .bottom:
            return .frameResize(position: .bottom, directions: directions)
        case .bottomRight:
            return .frameResize(position: .bottomRight, directions: directions)
        }
    }

    // MARK: - Helpers

    private func rectFrom(_ pointA: CGPoint, to pointB: CGPoint) -> CGRect {
        CGRect(
            x: min(pointA.x, pointB.x),
            y: min(pointA.y, pointB.y),
            width: abs(pointB.x - pointA.x),
            height: abs(pointB.y - pointA.y)
        )
    }

    private func clampToView(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: max(0, min(point.x, bounds.width)),
            y: max(0, min(point.y, bounds.height))
        )
    }

    private func enforceMinimumSize() {
        if selectionRect.width < minimumSize {
            selectionRect.size.width = minimumSize
        }
        if selectionRect.height < minimumSize {
            selectionRect.size.height = minimumSize
        }
    }

    private func confirmSelectionIfValid() {
        guard selectionRect.width >= minimumSize && selectionRect.height >= minimumSize else { return }

        // Convert from view coordinates to screen coordinates
        // The view fills the panel, which covers the screen frame
        let screenOrigin = screen.frame.origin
        let screenRect = CGRect(
            x: screenOrigin.x + selectionRect.origin.x,
            y: screenOrigin.y + selectionRect.origin.y,
            width: selectionRect.width,
            height: selectionRect.height
        )

        delegate?.areaSelectionView(self, didConfirmSelection: screenRect, on: screen)
    }
}
