//
//  ControlCommandHandler.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 20.11.26.
//

import AppKit
import OSLog
import ScreenCaptureKit

/// Carries out commands from the `bettercapture` command-line tool.
///
/// Every recording started from the command line is a separate ``RecordingSession``, so any
/// number of them can run at once. They are independent of the recording controlled from
/// the menu bar, which the command line doesn't see.
final class ControlCommandHandler {

    private let settings: SettingsStore
    private let notificationService: NotificationService
    private let sessions = RecordingSessionStore()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture", category: "ControlCommandHandler")

    init(settings: SettingsStore, notificationService: NotificationService) {
        self.settings = settings
        self.notificationService = notificationService
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
        guard settings.allowCommandLineControl else {
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
        case .status(let selector):
            let matching = try selector.map { [try sessions.session(matching: $0)] } ?? sessions.sessions
            return .recordings(matching.map(\.info))
        case .listDisplays:
            return .displays(try await shareableContent().displays.map(displayInfo))
        case .listWindows:
            return .windows(try await capturableWindows().map(windowInfo))
        case .listApps:
            return .apps(try await capturableApps().map(appInfo))
        case .record(let options):
            return .recording(try await record(options))
        case .stop(_, all: true, let copyToClipboard):
            return .recordings(await stopAll(copyToClipboard: copyToClipboard))
        case .stop(let selector, all: false, let copyToClipboard):
            return .recording(try await stop(selector, copyToClipboard: copyToClipboard))
        case .pause(let selector):
            return .recording(try pause(selector))
        case .resume(let selector):
            return .recording(try resume(selector))
        case .wait(let selector):
            return .recording(try await wait(for: selector))
        }
    }

    // MARK: - Recording

    private func record(_ options: RecordOptions) async throws -> RecordingInfo {
        let selection = try await contentSelection(for: options.target)
        let session = RecordingSession(
            id: sessions.makeID(),
            name: options.name,
            target: selection.description,
            settings: settings,
            notificationService: notificationService
        )

        do {
            try await session.start(
                filter: selection.filter,
                sourceRect: selection.sourceRect,
                screen: selection.screen,
                durationSeconds: options.durationSeconds
            )
        } catch {
            throw controlError(for: error)
        }

        sessions.add(session)
        return session.info
    }

    private func stop(_ selector: RecordingSelector?, copyToClipboard: Bool) async throws -> RecordingInfo {
        let session = try sessions.session(matching: selector)
        guard !session.hasEnded else { throw notRecording(session) }

        // A recording already stopping, such as at the end of its duration, is waited for
        await session.stop(copyToClipboard: copyToClipboard)
        await session.waitUntilEnded()
        return try endedRecording(session)
    }

    /// Stops every active recording at once. Failures are reported per recording.
    private func stopAll(copyToClipboard: Bool) async -> [RecordingInfo] {
        let active = sessions.activeSessions

        await withTaskGroup { group in
            for session in active {
                // Only one file fits on the clipboard
                let copies = copyToClipboard && active.count == 1
                group.addTask { await session.stop(copyToClipboard: copies) }
            }
        }

        return active.map(\.info)
    }

    private func pause(_ selector: RecordingSelector?) throws -> RecordingInfo {
        let session = try sessions.session(matching: selector)
        guard session.state == .recording else {
            throw ControlError(code: .notRecording, message: "Recording \(session.id) isn't running.")
        }
        session.pause()
        return session.info
    }

    private func resume(_ selector: RecordingSelector?) throws -> RecordingInfo {
        let session = try sessions.session(matching: selector)
        guard session.state == .paused else {
            throw ControlError(code: .notRecording, message: "Recording \(session.id) isn't paused.")
        }
        session.resume()
        return session.info
    }

    /// Waits until the recording ends. A recording that already ended is returned right away.
    private func wait(for selector: RecordingSelector?) async throws -> RecordingInfo {
        let session = try sessions.session(matching: selector)
        await session.waitUntilEnded()
        return try endedRecording(session)
    }

    /// The recording, or the error that kept it from being saved
    private func endedRecording(_ session: RecordingSession) throws -> RecordingInfo {
        guard session.state == .finished else {
            throw controlError(for: session.error)
        }
        return session.info
    }

    private func notRecording(_ session: RecordingSession) -> ControlError {
        ControlError(code: .notRecording, message: "Recording \(session.id) has already ended.")
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
        /// What is recorded, in words, see ``RecordingInfo/target``
        var description: String
        var filter: SCContentFilter
        var sourceRect: CGRect?
        var screen: NSScreen?
    }

    private func contentSelection(for target: CaptureTarget) async throws -> ContentSelection {
        switch target {
        case .display(let query):
            let display = try await resolveDisplay(query)
            return ContentSelection(
                description: "display \(display.displayID)",
                filter: SCContentFilter(display: display, excludingWindows: [])
            )

        case .window(let query):
            let candidates = try await capturableWindows().map {
                TargetResolver.Candidate(item: $0, id: String($0.windowID), name: $0.title ?? "")
            }
            let window = try TargetResolver.resolve(query, in: candidates, kind: "window")
            return ContentSelection(
                description: "window \(window.windowID) \"\(window.title ?? "")\"",
                filter: SCContentFilter(desktopIndependentWindow: window)
            )

        case .app(let query):
            let candidates = try await capturableApps().map {
                TargetResolver.Candidate(item: $0, id: $0.bundleIdentifier, name: $0.applicationName)
            }
            let app = try TargetResolver.resolve(query, in: candidates, kind: "app")
            let display = try await display(showing: app)
            return ContentSelection(
                description: "app \(app.bundleIdentifier)",
                filter: SCContentFilter(display: display, including: [app], exceptingWindows: [])
            )

        case .area(let area, let displayQuery):
            let display = try await resolveDisplay(displayQuery)
            let screen = screen(for: display.displayID)
            let sourceRect = try TargetResolver.sourceRect(
                for: area,
                displaySize: CGSize(width: display.width, height: display.height),
                scale: screen?.backingScaleFactor ?? 2
            )
            return ContentSelection(
                description: "area \(Int(area.left)),\(Int(area.top)),\(Int(area.width)),\(Int(area.height)) of display \(display.displayID)",
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
        return try TargetResolver.resolve(query, in: candidates, kind: "display")
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
