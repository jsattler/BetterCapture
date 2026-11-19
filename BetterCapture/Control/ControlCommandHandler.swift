//
//  ControlCommandHandler.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 20.11.26.
//

import AppKit
import Observation
import OSLog
import ScreenCaptureKit

/// Carries out commands from the `bettercapture` command-line tool on the shared recorder.
///
/// The command line and the menu bar act on the same ``RecorderViewModel``, so a recording
/// started from either one can be paused or stopped from the other.
final class ControlCommandHandler {

    private let viewModel: RecorderViewModel
    private var durationTask: Task<Void, Never>?

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture", category: "ControlCommandHandler")

    init(viewModel: RecorderViewModel) {
        self.viewModel = viewModel
    }

    func handle(_ request: ControlRequest) async -> ControlResponse {
        guard request.version == ControlProtocol.version else {
            return .failure(ControlError(
                code: .unsupportedVersion,
                message: "The command-line tool and BetterCapture don't match. Update BetterCapture and use the tool inside it."
            ))
        }

        // Without this opt-in, any local process could record the screen using
        // BetterCapture's Screen Recording permission
        guard viewModel.settings.allowCommandLineControl else {
            return .failure(ControlError(
                code: .disabled,
                message: "Command-line control is turned off. Turn it on in BetterCapture Settings → Command Line."
            ))
        }

        logger.info("Handling command: \(String(describing: request.command))")

        do {
            return .success(try await perform(request.command))
        } catch let error as ControlError {
            return .failure(error)
        } catch {
            return .failure(ControlError(code: .failed, message: error.localizedDescription))
        }
    }

    private func perform(_ command: ControlCommand) async throws -> ControlResult {
        switch command {
        case .status:
            return .status(status())
        case .listDisplays:
            return .displays(try await shareableContent().displays.map(displayInfo))
        case .listWindows:
            return .windows(try await capturableWindows().map(windowInfo))
        case .listApps:
            return .apps(try await capturableApps().map(appInfo))
        case .record(let options):
            return .status(try await record(options))
        case .stop(let copyToClipboard):
            return .recording(try await stop(copyToClipboard: copyToClipboard))
        case .pause:
            return .status(try togglePause(from: .recording))
        case .resume:
            return .status(try togglePause(from: .paused))
        case .wait:
            return .recording(try await waitForRecording())
        }
    }

    // MARK: - Recording

    private func record(_ options: RecordOptions) async throws -> RecorderStatus {
        guard viewModel.state == .idle else {
            throw ControlError(code: .alreadyRecording, message: "A recording is already in progress. Stop it first.")
        }

        let selection = try await contentSelection(for: options.target)
        try await viewModel.selectContent(selection.filter, sourceRect: selection.sourceRect, screen: selection.screen)
        await viewModel.startRecording()

        guard viewModel.isRecording, let outputURL = viewModel.currentOutputURL else {
            throw controlError(for: viewModel.lastError)
        }

        if let durationSeconds = options.durationSeconds {
            scheduleStop(of: outputURL, after: durationSeconds)
        }

        return status()
    }

    private func stop(copyToClipboard: Bool) async throws -> RecordingInfo {
        guard viewModel.isRecording, let outputURL = viewModel.currentOutputURL else { throw notRecording }

        await viewModel.stopRecording(copyToClipboard: copyToClipboard)
        return try finishedRecording(outputURL)
    }

    /// Pauses a running recording or resumes a paused one, as long as it is in the expected state
    private func togglePause(from expectedState: RecorderViewModel.RecordingState) throws -> RecorderStatus {
        guard viewModel.state == expectedState else {
            throw expectedState == .paused
                ? ControlError(code: .notRecording, message: "No recording is paused.")
                : notRecording
        }
        viewModel.togglePause()
        return status()
    }

    private func waitForRecording() async throws -> RecordingInfo {
        guard viewModel.state != .idle, let outputURL = viewModel.currentOutputURL else { throw notRecording }

        while viewModel.state != .idle {
            await withCheckedContinuation { continuation in
                withObservationTracking {
                    _ = viewModel.state
                } onChange: {
                    continuation.resume()
                }
            }
        }

        return try finishedRecording(outputURL)
    }

    /// The result of a recording that has just ended, or the error that kept it from being saved
    private func finishedRecording(_ outputURL: URL) throws -> RecordingInfo {
        guard viewModel.lastRecordingURL == outputURL else {
            throw controlError(for: viewModel.lastError)
        }
        return RecordingInfo(outputPath: outputURL.path(percentEncoded: false))
    }

    private func scheduleStop(of outputURL: URL, after seconds: Double) {
        durationTask?.cancel()
        durationTask = Task { [viewModel] in
            try? await Task.sleep(for: .seconds(seconds))

            // The recording may have been stopped, and another one started, in the meantime
            guard !Task.isCancelled, viewModel.currentOutputURL == outputURL else { return }
            await viewModel.stopRecording()
        }
    }

    private func status() -> RecorderStatus {
        let state = switch viewModel.state {
        case .idle: "idle"
        case .recording: "recording"
        case .paused: "paused"
        case .stopping: "stopping"
        }

        return RecorderStatus(
            state: state,
            durationSeconds: viewModel.recordingDuration,
            outputPath: viewModel.currentOutputURL?.path(percentEncoded: false)
        )
    }

    private var notRecording: ControlError {
        ControlError(code: .notRecording, message: "No recording is in progress.")
    }

    private func controlError(for error: Error?) -> ControlError {
        switch error as? CaptureError {
        case .screenRecordingPermissionDenied, .microphonePermissionDenied, .cameraPermissionDenied:
            ControlError(code: .permissionDenied, message: error?.localizedDescription ?? "")
        default:
            ControlError(code: .failed, message: error?.localizedDescription ?? "The recording failed.")
        }
    }

    // MARK: - Content Selection

    private struct ContentSelection {
        var filter: SCContentFilter
        var sourceRect: CGRect?
        var screen: NSScreen?
    }

    private func contentSelection(for target: CaptureTarget) async throws -> ContentSelection {
        switch target {
        case .display(let query):
            let display = try await resolveDisplay(query)
            return ContentSelection(filter: SCContentFilter(display: display, excludingWindows: []))

        case .window(let query):
            let candidates = try await capturableWindows().map {
                TargetResolver.Candidate(item: $0, id: String($0.windowID), name: $0.title ?? "")
            }
            let window = try TargetResolver.resolve(query, in: candidates, kind: "Window")
            return ContentSelection(filter: SCContentFilter(desktopIndependentWindow: window))

        case .app(let query):
            let candidates = try await capturableApps().map {
                TargetResolver.Candidate(item: $0, id: $0.bundleIdentifier, name: $0.applicationName)
            }
            let app = try TargetResolver.resolve(query, in: candidates, kind: "App")
            let display = try await display(showing: app)
            return ContentSelection(filter: SCContentFilter(display: display, including: [app], exceptingWindows: []))

        case .area(let area, let displayQuery):
            let display = try await resolveDisplay(displayQuery)
            let screen = screen(for: display.displayID)
            let sourceRect = try TargetResolver.sourceRect(
                for: area,
                displaySize: CGSize(width: display.width, height: display.height),
                scale: screen?.backingScaleFactor ?? 2
            )
            return ContentSelection(
                filter: SCContentFilter(display: display, excludingWindows: []),
                sourceRect: sourceRect,
                screen: screen
            )
        }
    }

    private func resolveDisplay(_ query: String) async throws -> SCDisplay {
        let displays = try await shareableContent().displays

        if query.compare("main", options: .caseInsensitive) == .orderedSame,
           let main = displays.first(where: { $0.displayID == CGMainDisplayID() }) {
            return main
        }

        let candidates = displays.map {
            TargetResolver.Candidate(item: $0, id: String($0.displayID), name: screen(for: $0.displayID)?.localizedName ?? "")
        }
        return try TargetResolver.resolve(query, in: candidates, kind: "Display")
    }

    /// The display an application's largest window is on, so its capture is framed around it
    private func display(showing app: SCRunningApplication) async throws -> SCDisplay {
        let content = try await shareableContent()
        let largestWindow = try await capturableWindows()
            .filter { $0.owningApplication?.processID == app.processID }
            .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }

        let display = largestWindow.flatMap { window in
            content.displays.first { $0.frame.contains(CGPoint(x: window.frame.midX, y: window.frame.midY)) }
        } ?? content.displays.first { $0.displayID == CGMainDisplayID() } ?? content.displays.first

        guard let display else {
            throw ControlError(code: .notFound, message: "No display is connected.")
        }
        return display
    }

    // MARK: - Shareable Content

    private func shareableContent() async throws -> SCShareableContent {
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            throw controlError(for: CaptureError.screenRecordingPermissionDenied)
        }
        return try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
    }

    /// Normal, titled on-screen windows of other apps
    private func capturableWindows() async throws -> [SCWindow] {
        try await shareableContent().windows.filter { window in
            window.windowLayer == 0
                && !(window.title ?? "").isEmpty
                && window.frame.width > 1 && window.frame.height > 1
                && window.owningApplication.map { $0.bundleIdentifier != Bundle.main.bundleIdentifier } ?? false
        }
    }

    /// Apps that own at least one capturable window
    private func capturableApps() async throws -> [SCRunningApplication] {
        var seen = Set<pid_t>()
        return try await capturableWindows()
            .compactMap(\.owningApplication)
            .filter { seen.insert($0.processID).inserted }
    }

    private func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first {
            $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID == displayID
        }
    }

    // MARK: - Info

    private func displayInfo(_ display: SCDisplay) -> DisplayInfo {
        DisplayInfo(
            id: display.displayID,
            name: screen(for: display.displayID)?.localizedName ?? "",
            isMain: display.displayID == CGMainDisplayID(),
            width: display.width,
            height: display.height
        )
    }

    private func windowInfo(_ window: SCWindow) -> WindowInfo {
        WindowInfo(
            id: window.windowID,
            title: window.title ?? "",
            appName: window.owningApplication?.applicationName ?? "",
            bundleID: window.owningApplication?.bundleIdentifier ?? ""
        )
    }

    private func appInfo(_ app: SCRunningApplication) -> AppInfo {
        AppInfo(bundleID: app.bundleIdentifier, name: app.applicationName)
    }
}
