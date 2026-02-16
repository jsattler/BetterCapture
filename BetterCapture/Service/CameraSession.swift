//
//  CameraSession.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 14.02.26.
//

import AVFoundation
import OSLog

/// Manages a minimal AVCaptureSession so the system recognises an active camera
/// and makes Presenter Overlay available in the Video menu bar item.
@MainActor
final class CameraSession {

    private var session: AVCaptureSession?

    /// Dedicated queue — `startRunning` / `stopRunning` block and must not run on the main thread.
    private let queue = DispatchQueue(label: "com.bettercapture.cameraSession")

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture",
        category: "CameraSession"
    )

    /// Starts a capture session with the specified camera, falling back to the system default.
    ///
    /// An `AVCaptureVideoDataOutput` is attached so the system considers the
    /// camera hardware active (an input alone is not enough). All delivered
    /// frames are discarded — only the session's existence matters for
    /// Presenter Overlay.
    ///
    /// `startRunning()` blocks until the session is fully running, so it is
    /// dispatched off the main thread and this method suspends until it
    /// completes. This guarantees the camera is active before the caller
    /// starts the `SCStream`.
    ///
    /// - Parameter deviceID: The unique ID of the camera to use, or `nil` for the system default.
    func start(deviceID: String? = nil) async {
        guard session == nil else { return }

        let device: AVCaptureDevice? = if let deviceID {
            AVCaptureDevice(uniqueID: deviceID)
        } else {
            AVCaptureDevice.default(for: .video)
        }

        guard let device else {
            logger.warning("No camera available for Presenter Overlay")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            let newSession = AVCaptureSession()

            newSession.beginConfiguration()

            guard newSession.canAddInput(input) else {
                logger.error("Cannot add camera input to session")
                return
            }
            newSession.addInput(input)

            // An output is required for the system to consider the camera active.
            let output = AVCaptureVideoDataOutput()
            guard newSession.canAddOutput(output) else {
                logger.error("Cannot add video output to session")
                return
            }
            newSession.addOutput(output)

            newSession.commitConfiguration()

            session = newSession

            // Wait for the session to actually be running before returning.
            // AVCaptureSession is not Sendable, but we fully configure it on
            // the main actor above and then only touch it on `queue` below.
            nonisolated(unsafe) let runnable = newSession
            let isRunning = await withCheckedContinuation { continuation in
                queue.async {
                    runnable.startRunning()
                    continuation.resume(returning: runnable.isRunning)
                }
            }

            logger.info("Camera session started for Presenter Overlay (running: \(isRunning))")
        } catch {
            logger.error("Failed to start camera session: \(error.localizedDescription)")
        }
    }

    /// Stops the capture session and releases resources.
    func stop() {
        guard let current = session else { return }
        session = nil

        // See comment in start(deviceID:) for why nonisolated(unsafe) is appropriate.
        nonisolated(unsafe) let stoppable = current
        queue.async {
            stoppable.stopRunning()
        }

        logger.info("Camera session stopped")
    }
}
