//
//  CaptureSizeCalculator+ContentFilter.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 20.11.26.
//

import AppKit
import ScreenCaptureKit

extension CaptureSizeCalculator {

    /// The dimensions to capture a content filter at.
    ///
    /// - Parameters:
    ///   - filter: The content to capture.
    ///   - sourceRect: The area to capture within a display filter, already snapped to even pixel counts.
    ///   - useNativeResolution: Whether to capture at the display's native pixel density.
    @MainActor
    static func videoSize(for filter: SCContentFilter, sourceRect: CGRect?, useNativeResolution: Bool) -> CGSize {
        if let sourceRect {
            return videoSize(
                contentRect: sourceRect,
                scale: CGFloat(filter.pointPixelScale),
                useNativeResolution: useNativeResolution
            )
        }

        let rect = filter.contentRect

        if rect.width > 0 && rect.height > 0 {
            return videoSize(
                contentRect: rect,
                scale: pointPixelScale(for: filter),
                useNativeResolution: useNativeResolution
            )
        }

        // Fallback to main screen size
        if let screen = NSScreen.main {
            return CGSize(
                width: useNativeResolution ? screen.frame.width * screen.backingScaleFactor : screen.frame.width,
                height: useNativeResolution ? screen.frame.height * screen.backingScaleFactor : screen.frame.height
            )
        }

        return CGSize(width: 1920, height: 1080)
    }

    /// The point-to-pixel scale to size the capture with.
    ///
    /// Window captures cannot trust `SCContentFilter.pointPixelScale`: it reports the main
    /// display's scale for a window on a display arranged above the primary one, which sizes the
    /// video larger than ScreenCaptureKit renders and pads the output. Resolve the scale from the
    /// display the window actually occupies instead.
    @MainActor
    private static func pointPixelScale(for filter: SCContentFilter) -> CGFloat {
        let reported = CGFloat(filter.pointPixelScale)

        guard filter.style == .window, let window = filter.includedWindows.first else {
            return reported
        }

        return windowScale(
            windowFrame: window.frame,
            displays: connectedDisplays(),
            fallback: reported
        )
    }

    /// The connected displays in the global CoreGraphics space that `SCWindow.frame` uses.
    @MainActor
    private static func connectedDisplays() -> [DisplayGeometry] {
        NSScreen.screens.compactMap { screen in
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return nil
            }
            return DisplayGeometry(frame: CGDisplayBounds(displayID), scaleFactor: screen.backingScaleFactor)
        }
    }
}
