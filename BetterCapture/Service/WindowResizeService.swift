//
//  WindowResizeService.swift
//  BetterCapture
//
//  Created by Karel Busta on 13.05.26.
//

import AppKit
@preconcurrency import ApplicationServices
import CoreGraphics
import Foundation
import ScreenCaptureKit

enum WindowResizeError: LocalizedError {
    case accessibilityPermissionMissing
    case windowUnavailable
    case resizeUnsupported
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionMissing:
            "Allow Accessibility access for BetterCapture, then try resizing again."
        case .windowUnavailable:
            "That window is no longer available for resizing."
        case .resizeUnsupported:
            "That window does not allow resizing."
        case .operationFailed(let message):
            message
        }
    }
}

@MainActor
struct WindowResizeService {
    func resize(_ window: SCWindow, to preset: WindowResizePreset) throws -> CGRect {
        guard isAccessibilityTrusted(prompt: true) else {
            throw WindowResizeError.accessibilityPermissionMissing
        }

        guard let target = WindowResizeTarget(window: window),
              let accessibilityWindow = matchingAccessibilityWindow(for: target) else {
            throw WindowResizeError.windowUnavailable
        }

        guard accessibilityWindow.isResizable else {
            throw WindowResizeError.resizeUnsupported
        }

        let visibleFrame = visibleFrame(containing: target.frame)
        let targetFrame = WindowResizeLayout.targetFrame(
            for: preset,
            currentFrame: target.frame,
            visibleFrame: visibleFrame
        )

        try accessibilityWindow.setFrame(targetFrame)
        return accessibilityWindow.frame ?? targetFrame
    }

    private func isAccessibilityTrusted(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func matchingAccessibilityWindow(for target: WindowResizeTarget) -> AccessibilityWindow? {
        let application = AXUIElementCreateApplication(target.processID)
        var rawWindows: CFTypeRef?

        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &rawWindows) == .success,
              let windows = rawWindows as? [AXUIElement],
              !windows.isEmpty else {
            return nil
        }

        return windows
            .compactMap { AccessibilityWindow(element: $0) }
            .min { first, second in
                matchScore(first, target: target) < matchScore(second, target: target)
            }
    }

    private func matchScore(_ candidate: AccessibilityWindow, target: WindowResizeTarget) -> CGFloat {
        guard let candidateFrame = candidate.frame else { return .greatestFiniteMagnitude }

        let centerDistance = candidateFrame.center.distance(to: target.frame.center)
        let sizeDelta = abs(candidateFrame.width - target.frame.width)
            + abs(candidateFrame.height - target.frame.height)
        let titlePenalty: CGFloat

        if target.title.isEmpty || candidate.title.isEmpty || candidate.title == target.title {
            titlePenalty = 0
        } else {
            titlePenalty = 220
        }

        return centerDistance + sizeDelta * 0.5 + titlePenalty
    }

    private func visibleFrame(containing frame: CGRect) -> CGRect {
        guard let screen = screen(containing: frame) ?? NSScreen.main else {
            return frame
        }

        return quartzVisibleFrame(for: screen)
    }

    private func screen(containing frame: CGRect) -> NSScreen? {
        NSScreen.screens.max { first, second in
            first.quartzFrame.intersectionArea(with: frame) < second.quartzFrame.intersectionArea(with: frame)
        }
    }

    private func quartzVisibleFrame(for screen: NSScreen) -> CGRect {
        let desktopFrame = NSScreen.screens.reduce(CGRect.null) { partialResult, screen in
            partialResult.union(screen.frame)
        }
        let visibleFrame = screen.visibleFrame

        return CGRect(
            x: visibleFrame.minX,
            y: desktopFrame.maxY - visibleFrame.maxY,
            width: visibleFrame.width,
            height: visibleFrame.height
        )
    }
}

private struct WindowResizeTarget {
    let title: String
    let processID: pid_t
    let frame: CGRect

    init?(window: SCWindow) {
        guard let processID = window.owningApplication?.processID else {
            return nil
        }

        self.title = window.title ?? ""
        self.processID = processID
        self.frame = window.frame.integral
    }
}

private struct AccessibilityWindow {
    let element: AXUIElement

    var title: String {
        stringValue(for: kAXTitleAttribute) ?? ""
    }

    var frame: CGRect? {
        guard let position, let size else { return nil }
        return CGRect(origin: position, size: size).integral
    }

    var isResizable: Bool {
        isAttributeSettable(kAXSizeAttribute)
    }

    func setFrame(_ frame: CGRect) throws {
        try setSize(frame.size)
        try setPosition(frame.origin)
    }

    private var position: CGPoint? {
        pointValue(for: kAXPositionAttribute)
    }

    private var size: CGSize? {
        sizeValue(for: kAXSizeAttribute)
    }

    private func isAttributeSettable(_ attribute: String) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, attribute as CFString, &settable) == .success
            && settable.boolValue
    }

    private func setPosition(_ position: CGPoint) throws {
        var mutablePosition = position
        guard let value = AXValueCreate(.cgPoint, &mutablePosition),
              AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value) == .success else {
            throw WindowResizeError.operationFailed("Could not move that window.")
        }
    }

    private func setSize(_ size: CGSize) throws {
        var mutableSize = size
        guard let value = AXValueCreate(.cgSize, &mutableSize),
              AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value) == .success else {
            throw WindowResizeError.operationFailed("Could not resize that window.")
        }
    }

    private func stringValue(for attribute: String) -> String? {
        var rawValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &rawValue) == .success else {
            return nil
        }

        return rawValue as? String
    }

    private func pointValue(for attribute: String) -> CGPoint? {
        var rawValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &rawValue) == .success,
              let rawValue,
              CFGetTypeID(rawValue) == AXValueGetTypeID() else {
            return nil
        }

        // swiftlint:disable:next force_cast
        let value = rawValue as! AXValue
        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else { return nil }
        return point
    }

    private func sizeValue(for attribute: String) -> CGSize? {
        var rawValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &rawValue) == .success,
              let rawValue,
              CFGetTypeID(rawValue) == AXValueGetTypeID() else {
            return nil
        }

        // swiftlint:disable:next force_cast
        let value = rawValue as! AXValue
        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else { return nil }
        return size
    }
}

private extension NSScreen {
    var quartzFrame: CGRect {
        let desktopFrame = NSScreen.screens.reduce(CGRect.null) { partialResult, screen in
            partialResult.union(screen.frame)
        }

        return CGRect(
            x: frame.minX,
            y: desktopFrame.maxY - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }

    func intersectionArea(with rect: CGRect) -> CGFloat {
        let intersection = intersection(rect)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }
}

private extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        hypot(x - point.x, y - point.y)
    }
}
