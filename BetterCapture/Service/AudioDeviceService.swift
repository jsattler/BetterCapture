//
//  AudioDeviceService.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 02.02.26.
//

import AVFoundation
import OSLog

/// Represents an audio input device
struct AudioInputDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let isDefault: Bool
}

/// Service for enumerating and monitoring available microphone devices
@MainActor
@Observable
final class AudioDeviceService {

    // MARK: - Properties

    private(set) var availableDevices: [AudioInputDevice] = []

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture",
        category: "AudioDeviceService"
    )

    // MARK: - Initialization

    init() {
        refreshDevices()
        setupNotifications()
    }

    // MARK: - Public Methods

    /// Refreshes the list of available audio input devices
    func refreshDevices() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        )

        availableDevices = discoverySession.devices.map { device in
            AudioInputDevice(
                id: device.uniqueID,
                name: device.localizedName,
                isDefault: false
            )
        }

        logger.info("Found \(self.availableDevices.count) audio input devices")
    }

    // MARK: - Private Methods

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.wasConnectedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshDevices()
                self?.logger.info("Audio device connected")
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.wasDisconnectedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshDevices()
                self?.logger.info("Audio device disconnected")
            }
        }
    }
}
