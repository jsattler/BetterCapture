//
//  SettingsStoreTests.swift
//  BetterCaptureTests
//
//  Created by Joshua Sattler on 28.03.26.
//

import Testing
import Foundation
@testable import BetterCapture

/// Tests for SettingsStore's codec/container/alpha/HDR/audio validation logic.
///
/// Each test uses an isolated UserDefaults suite to avoid cross-test pollution.
@MainActor
struct SettingsStoreTests {

    /// Creates a SettingsStore backed by a fresh, empty UserDefaults suite.
    private func makeStore() -> SettingsStore {
        let suiteName = "com.sattlerjoshua.BetterCaptureTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return SettingsStore(defaults: defaults)
    }

    // MARK: - Default Values

    @Test func defaultVideoCodecIsHEVC() {
        let store = makeStore()
        #expect(store.videoCodec == .hevc)
    }

    @Test func defaultContainerFormatIsMOV() {
        let store = makeStore()
        #expect(store.containerFormat == .mov)
    }

    @Test func defaultFrameRateIs60() {
        let store = makeStore()
        #expect(store.frameRate == .fps60)
    }

    @Test func defaultVideoQualityIsMedium() {
        let store = makeStore()
        #expect(store.videoQuality == .medium)
    }

    @Test func defaultAudioCodecIsAAC() {
        let store = makeStore()
        #expect(store.audioCodec == .aac)
    }

    @Test func defaultHDRIsOff() {
        let store = makeStore()
        #expect(store.captureHDR == false)
    }

    @Test func defaultAlphaIsOff() {
        let store = makeStore()
        #expect(store.captureAlphaChannel == false)
    }

    @Test func defaultHDRPresetIsSDR() {
        let store = makeStore()
        #expect(store.hdrPreset == .sdr)
    }

    @Test func defaultCaptureNativeResolutionIsTrue() {
        let store = makeStore()
        #expect(store.captureNativeResolution == true)
    }

    @Test func defaultShowCursorIsTrue() {
        let store = makeStore()
        #expect(store.showCursor == true)
    }

    @Test func defaultShowBetterCaptureIsFalse() {
        let store = makeStore()
        #expect(store.showBetterCapture == false)
    }

    // MARK: - Codec/Container Compatibility

    @Test func settingProResToMP4SwitchesContainerToMOV() {
        let store = makeStore()
        store.containerFormat = .mp4
        store.videoCodec = .proRes422
        #expect(store.containerFormat == .mov)
        #expect(store.videoCodec == .proRes422)
    }

    @Test func settingProRes4444ToMP4SwitchesContainerToMOV() {
        let store = makeStore()
        store.containerFormat = .mp4
        store.videoCodec = .proRes4444
        #expect(store.containerFormat == .mov)
        #expect(store.videoCodec == .proRes4444)
    }

    @Test func switchingToMP4WithProResCodecSwitchesToHEVC() {
        let store = makeStore()
        store.videoCodec = .proRes422
        store.containerFormat = .mp4
        #expect(store.videoCodec == .hevc)
        #expect(store.containerFormat == .mp4)
    }

    @Test func h264AndHEVCWorkWithBothContainers() {
        let store = makeStore()

        store.containerFormat = .mp4
        store.videoCodec = .h264
        #expect(store.videoCodec == .h264)
        #expect(store.containerFormat == .mp4)

        store.videoCodec = .hevc
        #expect(store.videoCodec == .hevc)
        #expect(store.containerFormat == .mp4)

        store.containerFormat = .mov
        store.videoCodec = .h264
        #expect(store.videoCodec == .h264)
        #expect(store.containerFormat == .mov)
    }

    // MARK: - Alpha Channel Invariants

    @Test func proRes4444AlwaysHasAlpha() {
        let store = makeStore()
        store.videoCodec = .proRes4444
        #expect(store.captureAlphaChannel == true)

        // Attempting to disable alpha should have no effect
        store.captureAlphaChannel = false
        #expect(store.captureAlphaChannel == true)
    }

    @Test func h264NeverHasAlpha() {
        let store = makeStore()
        store.videoCodec = .h264
        #expect(store.captureAlphaChannel == false)

        store.captureAlphaChannel = true
        #expect(store.captureAlphaChannel == false)
    }

    @Test func proRes422NeverHasAlpha() {
        let store = makeStore()
        store.videoCodec = .proRes422
        #expect(store.captureAlphaChannel == false)

        store.captureAlphaChannel = true
        #expect(store.captureAlphaChannel == false)
    }

    @Test func mp4NeverHasAlpha() {
        let store = makeStore()
        store.containerFormat = .mp4
        store.videoCodec = .hevc
        #expect(store.captureAlphaChannel == false)

        store.captureAlphaChannel = true
        #expect(store.captureAlphaChannel == false)
    }

    @Test func hevcCanToggleAlphaInMOV() {
        let store = makeStore()
        store.videoCodec = .hevc
        store.containerFormat = .mov

        store.captureAlphaChannel = true
        #expect(store.captureAlphaChannel == true)

        store.captureAlphaChannel = false
        #expect(store.captureAlphaChannel == false)
    }

    @Test func switchingToProRes4444EnablesAlpha() {
        let store = makeStore()
        store.videoCodec = .hevc
        store.captureAlphaChannel = false
        store.videoCodec = .proRes4444
        #expect(store.captureAlphaChannel == true)
    }

    @Test func switchingFromProRes4444ToH264DisablesAlpha() {
        let store = makeStore()
        store.videoCodec = .proRes4444
        #expect(store.captureAlphaChannel == true)
        store.videoCodec = .h264
        #expect(store.captureAlphaChannel == false)
    }

    // MARK: - HDR Invariants

    @Test func h264CannotEnableHDR() {
        let store = makeStore()
        store.videoCodec = .h264
        store.captureHDR = true
        // HDR stays true in storage, but hdrPreset should still be SDR since h264 doesn't support it
        #expect(store.hdrPreset == .sdr)
    }

    @Test func switchingToH264DisablesHDR() {
        let store = makeStore()
        store.videoCodec = .hevc
        store.captureHDR = true
        store.videoCodec = .h264
        #expect(store.captureHDR == false)
    }

    // MARK: - HEVC Alpha/HDR Mutual Exclusion

    @Test func enablingHDROnHEVCDisablesAlpha() {
        let store = makeStore()
        store.videoCodec = .hevc
        store.containerFormat = .mov
        store.captureAlphaChannel = true
        #expect(store.captureAlphaChannel == true)

        store.captureHDR = true
        #expect(store.captureAlphaChannel == false)
    }

    @Test func enablingAlphaOnHEVCWithHDRIsPrevented() {
        let store = makeStore()
        store.videoCodec = .hevc
        store.containerFormat = .mov
        store.captureHDR = true

        store.captureAlphaChannel = true
        #expect(store.captureAlphaChannel == false)
    }

    @Test func settingHEVCWithHDROnDisablesAlpha() {
        let store = makeStore()
        store.captureHDR = true
        store.videoCodec = .hevc
        #expect(store.captureAlphaChannel == false)
    }

    // MARK: - HDR Preset

    @Test func hdrPresetSDRWhenHDROff() {
        let store = makeStore()
        store.captureHDR = false
        #expect(store.hdrPreset == .sdr)
    }

    @Test func hdrPresetSDRForH264EvenWhenHDROn() {
        let store = makeStore()
        store.videoCodec = .h264
        store.captureHDR = true
        #expect(store.hdrPreset == .sdr)
    }

    @Test func hdrPresetForHEVCWhenHDROn() {
        let store = makeStore()
        store.videoCodec = .hevc
        store.captureHDR = true
        // On macOS 26+ this should be .hdr10PreservedSDR, on older .hdr10Manual
        #expect(store.hdrPreset != .sdr)
    }

    @Test func hdrPresetForProRes422WhenHDROn() {
        let store = makeStore()
        store.videoCodec = .proRes422
        store.captureHDR = true
        #expect(store.hdrPreset != .sdr)
    }

    @Test func hdrPresetForProRes4444WhenHDROn() {
        let store = makeStore()
        store.videoCodec = .proRes4444
        store.captureHDR = true
        #expect(store.hdrPreset != .sdr)
    }

    // MARK: - Audio Codec Compatibility

    @Test func pcmAudioIncompatibleWithMP4SwitchesContainer() {
        let store = makeStore()
        store.containerFormat = .mp4
        store.audioCodec = .pcm
        // Setting PCM on MP4 should switch container to MOV
        #expect(store.containerFormat == .mov)
        #expect(store.audioCodec == .pcm)
    }

    @Test func switchingToMP4WithPCMSwitchesAudioToAAC() {
        let store = makeStore()
        store.audioCodec = .pcm
        store.containerFormat = .mp4
        #expect(store.audioCodec == .aac)
        #expect(store.containerFormat == .mp4)
    }

    @Test func aacWorksWithBothContainers() {
        let store = makeStore()

        store.containerFormat = .mov
        store.audioCodec = .aac
        #expect(store.audioCodec == .aac)

        store.containerFormat = .mp4
        #expect(store.audioCodec == .aac)
    }

    // MARK: - Filename Generation

    @Test func generateFilenameFormat() {
        let store = makeStore()
        let filename = store.generateFilename()

        #expect(filename.hasPrefix("BetterCapture_"))
        #expect(filename.hasSuffix(".\(store.containerFormat.fileExtension)"))
    }

    @Test func generateFilenameUsesContainerExtension() {
        let store = makeStore()

        store.containerFormat = .mov
        #expect(store.generateFilename().hasSuffix(".mov"))

        store.containerFormat = .mp4
        #expect(store.generateFilename().hasSuffix(".mp4"))
    }

    // MARK: - Output Directory

    @Test func defaultOutputDirectoryIsMoviesBetterCapture() {
        let store = makeStore()
        let expected = URL.homeDirectory.appending(path: "Movies/BetterCapture")
        #expect(store.defaultOutputDirectory == expected)
    }

    @Test func hasNoCustomOutputDirectoryByDefault() {
        let store = makeStore()
        #expect(store.hasCustomOutputDirectory == false)
    }

    @Test func outputDirectoryUsesDefaultWhenNoCustomSet() {
        let store = makeStore()
        #expect(store.outputDirectory == store.defaultOutputDirectory)
    }

    @Test func resetOutputDirectoryClearsCustom() {
        let store = makeStore()
        store.resetOutputDirectory()
        #expect(store.hasCustomOutputDirectory == false)
    }

    // MARK: - Setting Persistence

    @Test func frameRatePersists() {
        let store = makeStore()
        store.frameRate = .fps24
        #expect(store.frameRate == .fps24)
        store.frameRate = .native
        #expect(store.frameRate == .native)
    }

    @Test func videoQualityPersists() {
        let store = makeStore()
        store.videoQuality = .high
        #expect(store.videoQuality == .high)
        store.videoQuality = .low
        #expect(store.videoQuality == .low)
    }

    @Test func booleanSettingsPersist() {
        let store = makeStore()

        store.captureMicrophone = true
        #expect(store.captureMicrophone == true)

        store.captureSystemAudio = true
        #expect(store.captureSystemAudio == true)

        store.presenterOverlayEnabled = true
        #expect(store.presenterOverlayEnabled == true)

        store.showCursor = false
        #expect(store.showCursor == false)

        store.showWallpaper = false
        #expect(store.showWallpaper == false)

        store.showMenuBar = false
        #expect(store.showMenuBar == false)

        store.showDock = false
        #expect(store.showDock == false)

        store.showWindowShadows = false
        #expect(store.showWindowShadows == false)

        store.showBetterCapture = true
        #expect(store.showBetterCapture == true)

        store.captureNativeResolution = false
        #expect(store.captureNativeResolution == false)
    }

    // MARK: - Complex Cascade Scenarios

    @Test func mp4ToProRes4444CascadesCorrectly() {
        let store = makeStore()
        store.containerFormat = .mp4
        store.audioCodec = .aac

        // Setting ProRes 4444 should: switch container to MOV, enable alpha
        store.videoCodec = .proRes4444
        #expect(store.containerFormat == .mov)
        #expect(store.captureAlphaChannel == true)
        #expect(store.videoCodec == .proRes4444)
    }

    @Test func switchingContainerToMP4CascadesAllSettings() {
        let store = makeStore()
        // Start with a MOV-specific configuration
        store.videoCodec = .proRes4444
        store.audioCodec = .pcm
        #expect(store.captureAlphaChannel == true)

        // Switch to MP4 — should cascade: codec -> HEVC, alpha -> false, audio -> AAC
        store.containerFormat = .mp4
        #expect(store.videoCodec == .hevc)
        #expect(store.captureAlphaChannel == false)
        #expect(store.audioCodec == .aac)
    }
}
