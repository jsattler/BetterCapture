//
//  ContentFilterService.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 29.01.26.
//

import Foundation
import ScreenCaptureKit
import OSLog
import CoreGraphics
import AVFoundation

/// Service responsible for applying content filter settings (wallpaper, dock, menu bar)
@MainActor
final class ContentFilterService {

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture", category: "ContentFilterService")

    /// Checks if screen recording permission has been granted
    /// - Returns: true if permission is granted
    func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Requests screen recording permission from the user
    /// - Returns: true if permission was granted (or was already granted)
    @discardableResult
    func requestScreenRecordingPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    /// Checks if microphone permission has been granted
    /// - Returns: true if permission is granted
    func hasMicrophonePermission() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    /// Requests microphone permission from the user
    func requestMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    /// Applies user settings to a content filter for display capture
    /// - Parameters:
    ///   - filter: The original filter from the content picker
    ///   - settings: User settings for content visibility
    /// - Returns: A modified filter with settings applied
    func applySettings(to filter: SCContentFilter, settings: SettingsStore) async throws -> SCContentFilter {
        // Menu bar can be set directly on any filter
        filter.includeMenuBar = settings.showMenuBar

        // For wallpaper and dock exclusion, we need to rebuild the filter for display capture
        guard let display = filter.includedDisplays.first else {
            logger.info("Filter is not a display capture, returning with menu bar setting only")
            return filter
        }

        // If both wallpaper and dock are shown and BetterCapture is shown, no need to rebuild the filter
        if settings.showWallpaper && settings.showDock && settings.showBetterCapture {
            logger.info("No exclusions needed, returning original filter")
            return filter
        }

        // Check for screen recording permission before accessing SCShareableContent
        guard hasScreenRecordingPermission() else {
            logger.warning("Screen recording permission not granted, skipping window exclusions")
            return filter
        }

        // Get all available windows to find wallpaper/dock
        let content = try await SCShareableContent.current
        let availableWindows = content.windows.filter { $0.isOnScreen }

        var excludedWindows: [SCWindow] = []

        for window in availableWindows {
            let bundleID = window.owningApplication?.bundleIdentifier ?? ""
            let windowTitle = window.title ?? ""

            // Backstop is a macOS 26 layer behind wallpaper - exclude when hiding wallpaper
            // Note: Backstop may not be owned by com.apple.dock
            if !settings.showWallpaper && windowTitle.contains("Backstop") {
                excludedWindows.append(window)
                logger.debug("Excluding backstop window: \(windowTitle)")
                continue
            }

            // Exclude BetterCapture's own windows if showBetterCapture is false
            if !settings.showBetterCapture && bundleID == Bundle.main.bundleIdentifier {
                excludedWindows.append(window)
                logger.debug("Excluding BetterCapture window: \(windowTitle)")
                continue
            }

            // Wallpaper and Dock are both owned by com.apple.dock
            guard bundleID == "com.apple.dock" else { continue }

            let isWallpaper = windowTitle.hasPrefix("Wallpaper-")

            if !settings.showWallpaper && isWallpaper {
                excludedWindows.append(window)
                logger.debug("Excluding wallpaper window: \(windowTitle)")
            }

            if !settings.showDock && !isWallpaper {
                excludedWindows.append(window)
                logger.debug("Excluding dock window: \(windowTitle)")
            }
        }

        logger.info("Excluding \(excludedWindows.count) windows from capture")

        // Create new filter with excluded windows
        let newFilter = SCContentFilter(display: display, excludingWindows: excludedWindows)
        newFilter.includeMenuBar = settings.showMenuBar

        return newFilter
    }
}
