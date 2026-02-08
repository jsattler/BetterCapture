//
//  SettingsStore.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 29.01.26.
//

import AppKit
import Foundation

/// Video codec options for recording
enum VideoCodec: String, CaseIterable, Identifiable {
    case h264 = "H.264"
    case hevc = "H.265"
    case proRes422 = "ProRes 422"
    case proRes4444 = "ProRes 4444"

    var id: String { rawValue }

    /// Whether this codec supports alpha channel capture
    var supportsAlphaChannel: Bool {
        switch self {
        case .hevc, .proRes4444:
            return true
        case .h264, .proRes422:
            return false
        }
    }

    /// Whether alpha channel is always enabled (cannot be disabled)
    var alwaysHasAlpha: Bool {
        switch self {
        case .proRes4444:
            return true
        case .hevc, .h264, .proRes422:
            return false
        }
    }

    /// Whether alpha channel can be toggled by the user
    var canToggleAlpha: Bool {
        switch self {
        case .hevc:
            return true
        case .h264, .proRes422, .proRes4444:
            return false
        }
    }

    /// Whether this codec supports HDR (10-bit) recording
    var supportsHDR: Bool {
        switch self {
        case .proRes422, .proRes4444:
            return true
        case .h264, .hevc:
            return false
        }
    }
}

/// Container format for output files
enum ContainerFormat: String, CaseIterable, Identifiable {
    case mov = "mov"
    case mp4 = "mp4"

    var id: String { rawValue }

    var fileExtension: String { rawValue }

    /// Video codecs supported by this container format
    var supportedVideoCodecs: [VideoCodec] {
        switch self {
        case .mov:
            // MOV (QuickTime) supports all codecs including ProRes and HEVC with alpha
            return VideoCodec.allCases
        case .mp4:
            // MP4 (MPEG-4) only supports H.264 and HEVC (without alpha)
            return [.h264, .hevc]
        }
    }

    /// Whether this container supports alpha channel video
    var supportsAlphaChannel: Bool {
        switch self {
        case .mov:
            return true
        case .mp4:
            // MP4 does not support alpha channel (HEVC with alpha or ProRes 4444)
            return false
        }
    }

    /// Audio codecs supported by this container format
    var supportedAudioCodecs: [AudioCodec] {
        switch self {
        case .mov:
            // MOV supports all audio codecs
            return AudioCodec.allCases
        case .mp4:
            // MP4 only supports AAC (not raw PCM)
            return [.aac]
        }
    }
}

/// Audio codec options
enum AudioCodec: String, CaseIterable, Identifiable {
    case aac = "AAC"
    case pcm = "PCM"

    var id: String { rawValue }
}

/// Frame rate options for recording
enum FrameRate: Int, CaseIterable, Identifiable {
    case native = 0
    case fps24 = 24
    case fps30 = 30
    case fps60 = 60

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .native:
            return "Native"
        default:
            return "\(rawValue) fps"
        }
    }
}

/// Persists user preferences using AppStorage
@MainActor
@Observable
final class SettingsStore {

    // MARK: - Video Settings

    var frameRate: FrameRate {
        get {
            FrameRate(rawValue: frameRateRaw) ?? .fps60
        }
        set {
            frameRateRaw = newValue.rawValue
        }
    }

    var videoCodec: VideoCodec {
        get {
            VideoCodec(rawValue: videoCodecRaw) ?? .hevc
        }
        set {
            // Ensure the codec is compatible with the current container format
            guard containerFormat.supportedVideoCodecs.contains(newValue) else {
                // If codec is not compatible, switch to MOV container first
                containerFormatRaw = ContainerFormat.mov.rawValue
                videoCodecRaw = newValue.rawValue
                return
            }

            videoCodecRaw = newValue.rawValue

            // Set alpha channel based on codec and container capabilities
            if newValue.alwaysHasAlpha {
                // ProRes 4444 always has alpha, requires MOV container
                captureAlphaChannel = true
            } else if !newValue.supportsAlphaChannel || !containerFormat.supportsAlphaChannel {
                // H.264, ProRes 422 never have alpha, or container doesn't support it
                captureAlphaChannel = false
            }
            // HEVC can toggle alpha (if container supports it), so leave it as-is

            // Disable HDR for codecs that don't support it
            if !newValue.supportsHDR {
                captureHDR = false
            }
        }
    }

    var containerFormat: ContainerFormat {
        get {
            ContainerFormat(rawValue: containerFormatRaw) ?? .mov
        }
        set {
            containerFormatRaw = newValue.rawValue

            // Ensure current video codec is compatible with new container
            if !newValue.supportedVideoCodecs.contains(videoCodec) {
                // Switch to a compatible codec (prefer HEVC for quality)
                videoCodec = .hevc
            }

            // Disable alpha channel if container doesn't support it
            if !newValue.supportsAlphaChannel {
                captureAlphaChannel = false
            }

            // Ensure current audio codec is compatible with new container
            if !newValue.supportedAudioCodecs.contains(audioCodec) {
                audioCodec = .aac
            }
        }
    }

    var captureAlphaChannel: Bool {
        get {
            access(keyPath: \.captureAlphaChannel)
            // ProRes 4444 always has alpha regardless of stored value
            if videoCodec.alwaysHasAlpha {
                return true
            }
            // If codec or container doesn't support alpha, always return false
            if !videoCodec.supportsAlphaChannel || !containerFormat.supportsAlphaChannel {
                return false
            }
            return UserDefaults.standard.bool(forKey: "captureAlphaChannel")
        }
        set {
            // Only allow alpha channel if both codec and container support it
            let canEnable = videoCodec.supportsAlphaChannel && containerFormat.supportsAlphaChannel
            let finalValue = newValue && canEnable

            withMutation(keyPath: \.captureAlphaChannel) {
                UserDefaults.standard.set(finalValue, forKey: "captureAlphaChannel")
            }
        }
    }

    var captureHDR: Bool {
        get {
            access(keyPath: \.captureHDR)
            return UserDefaults.standard.bool(forKey: "captureHDR")
        }
        set {
            withMutation(keyPath: \.captureHDR) {
                UserDefaults.standard.set(newValue, forKey: "captureHDR")
            }
        }
    }

    // MARK: - Audio Settings

    var captureMicrophone: Bool {
        get {
            access(keyPath: \.captureMicrophone)
            return UserDefaults.standard.bool(forKey: "captureMicrophone")
        }
        set {
            withMutation(keyPath: \.captureMicrophone) {
                UserDefaults.standard.set(newValue, forKey: "captureMicrophone")
            }
        }
    }

    var captureSystemAudio: Bool {
        get {
            access(keyPath: \.captureSystemAudio)
            return UserDefaults.standard.bool(forKey: "captureSystemAudio")
        }
        set {
            withMutation(keyPath: \.captureSystemAudio) {
                UserDefaults.standard.set(newValue, forKey: "captureSystemAudio")
            }
        }
    }

    var audioCodec: AudioCodec {
        get {
            AudioCodec(rawValue: audioCodecRaw) ?? .aac
        }
        set {
            // Ensure the audio codec is compatible with the current container format
            guard containerFormat.supportedAudioCodecs.contains(newValue) else {
                // If codec is not compatible, switch to MOV container first
                containerFormatRaw = ContainerFormat.mov.rawValue
                audioCodecRaw = newValue.rawValue
                return
            }

            audioCodecRaw = newValue.rawValue
        }
    }

    var selectedMicrophoneID: String? {
        get {
            access(keyPath: \.selectedMicrophoneID)
            return UserDefaults.standard.string(forKey: "selectedMicrophoneID")
        }
        set {
            withMutation(keyPath: \.selectedMicrophoneID) {
                UserDefaults.standard.set(newValue, forKey: "selectedMicrophoneID")
            }
        }
    }

    // MARK: - Content Filter Settings

    var showCursor: Bool {
        get {
            access(keyPath: \.showCursor)
            return UserDefaults.standard.object(forKey: "showCursor") as? Bool ?? true
        }
        set {
            withMutation(keyPath: \.showCursor) {
                UserDefaults.standard.set(newValue, forKey: "showCursor")
            }
        }
    }

    var showWallpaper: Bool {
        get {
            access(keyPath: \.showWallpaper)
            return UserDefaults.standard.object(forKey: "showWallpaper") as? Bool ?? true
        }
        set {
            withMutation(keyPath: \.showWallpaper) {
                UserDefaults.standard.set(newValue, forKey: "showWallpaper")
            }
        }
    }

    var showMenuBar: Bool {
        get {
            access(keyPath: \.showMenuBar)
            return UserDefaults.standard.object(forKey: "showMenuBar") as? Bool ?? true
        }
        set {
            withMutation(keyPath: \.showMenuBar) {
                UserDefaults.standard.set(newValue, forKey: "showMenuBar")
            }
        }
    }

    var showDock: Bool {
        get {
            access(keyPath: \.showDock)
            return UserDefaults.standard.object(forKey: "showDock") as? Bool ?? true
        }
        set {
            withMutation(keyPath: \.showDock) {
                UserDefaults.standard.set(newValue, forKey: "showDock")
            }
        }
    }

    var showWindowShadows: Bool {
        get {
            access(keyPath: \.showWindowShadows)
            return UserDefaults.standard.object(forKey: "showWindowShadows") as? Bool ?? true
        }
        set {
            withMutation(keyPath: \.showWindowShadows) {
                UserDefaults.standard.set(newValue, forKey: "showWindowShadows")
            }
        }
    }

    var showBetterCapture: Bool {
        get {
            access(keyPath: \.showBetterCapture)
            return UserDefaults.standard.object(forKey: "showBetterCapture") as? Bool ?? false
        }
        set {
            withMutation(keyPath: \.showBetterCapture) {
                UserDefaults.standard.set(newValue, forKey: "showBetterCapture")
            }
        }
    }

    // MARK: - Update Settings

    var automaticallyCheckForUpdates: Bool {
        get {
            access(keyPath: \.automaticallyCheckForUpdates)
            return UserDefaults.standard.object(forKey: "automaticallyCheckForUpdates") as? Bool ?? true
        }
        set {
            withMutation(keyPath: \.automaticallyCheckForUpdates) {
                UserDefaults.standard.set(newValue, forKey: "automaticallyCheckForUpdates")
            }
        }
    }

    // MARK: - Output Settings

    /// The default output directory (Movies/BetterCapture)
    var defaultOutputDirectory: URL {
        URL.homeDirectory.appending(path: "Movies/BetterCapture")
    }

    /// Security-scoped bookmark data for the custom output directory
    private var customOutputDirectoryBookmark: Data? {
        get {
            access(keyPath: \.customOutputDirectoryBookmark)
            return UserDefaults.standard.data(forKey: "customOutputDirectoryBookmark")
        }
        set {
            withMutation(keyPath: \.customOutputDirectoryBookmark) {
                UserDefaults.standard.set(newValue, forKey: "customOutputDirectoryBookmark")
            }
        }
    }

    /// Whether a custom output directory has been set
    var hasCustomOutputDirectory: Bool {
        customOutputDirectoryBookmark != nil
    }

    /// The current output directory, using custom path if set
    var outputDirectory: URL {
        guard let bookmarkData = customOutputDirectoryBookmark else {
            return defaultOutputDirectory
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                // Bookmark is stale, try to recreate it
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let newBookmark = try? url.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    ) {
                        customOutputDirectoryBookmark = newBookmark
                    }
                }
            }

            return url
        } catch {
            // If bookmark resolution fails, fall back to default
            return defaultOutputDirectory
        }
    }

    /// Sets a custom output directory from a user-selected URL
    /// - Parameter url: The URL selected by the user via NSOpenPanel
    func setCustomOutputDirectory(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            customOutputDirectoryBookmark = bookmarkData
        } catch {
            // Failed to create bookmark, ignore
        }
    }

    /// Resets to the default output directory
    func resetOutputDirectory() {
        customOutputDirectoryBookmark = nil
    }

    /// Starts accessing the security-scoped output directory resource
    /// Call this before writing files to a custom output directory
    /// - Returns: Whether access was successfully started (always true for default directory)
    func startAccessingOutputDirectory() -> Bool {
        guard customOutputDirectoryBookmark != nil else {
            return true // Default directory doesn't need security scope
        }
        return outputDirectory.startAccessingSecurityScopedResource()
    }

    /// Stops accessing the security-scoped output directory resource
    func stopAccessingOutputDirectory() {
        guard customOutputDirectoryBookmark != nil else {
            return // Default directory doesn't need security scope
        }
        outputDirectory.stopAccessingSecurityScopedResource()
    }

    // MARK: - Private Storage

    private var frameRateRaw: Int {
        get {
            access(keyPath: \.frameRateRaw)
            let value = UserDefaults.standard.integer(forKey: "frameRate")
            return value == 0 ? 60 : value
        }
        set {
            withMutation(keyPath: \.frameRateRaw) {
                UserDefaults.standard.set(newValue, forKey: "frameRate")
            }
        }
    }

    private var videoCodecRaw: String {
        get {
            access(keyPath: \.videoCodecRaw)
            return UserDefaults.standard.string(forKey: "videoCodec") ?? VideoCodec.hevc.rawValue
        }
        set {
            withMutation(keyPath: \.videoCodecRaw) {
                UserDefaults.standard.set(newValue, forKey: "videoCodec")
            }
        }
    }

    private var containerFormatRaw: String {
        get {
            access(keyPath: \.containerFormatRaw)
            return UserDefaults.standard.string(forKey: "containerFormat") ?? ContainerFormat.mov.rawValue
        }
        set {
            withMutation(keyPath: \.containerFormatRaw) {
                UserDefaults.standard.set(newValue, forKey: "containerFormat")
            }
        }
    }

    private var audioCodecRaw: String {
        get {
            access(keyPath: \.audioCodecRaw)
            return UserDefaults.standard.string(forKey: "audioCodec") ?? AudioCodec.aac.rawValue
        }
        set {
            withMutation(keyPath: \.audioCodecRaw) {
                UserDefaults.standard.set(newValue, forKey: "audioCodec")
            }
        }
    }

    // MARK: - Helper Methods

    /// Generates a filename based on the current timestamp
    func generateFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH.mm.ss"
        let timestamp = formatter.string(from: Date())
        return "BetterCapture_\(timestamp).\(containerFormat.fileExtension)"
    }

    /// Returns the full output URL for a new recording
    func generateOutputURL() -> URL {
        outputDirectory.appending(path: generateFilename())
    }
}
