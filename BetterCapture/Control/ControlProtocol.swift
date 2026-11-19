//
//  ControlProtocol.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 20.11.26.
//

import Foundation

/// The messages the `bettercapture` command-line tool and the app exchange over the
/// control socket.
///
/// Each connection carries exactly one request and one response, each encoded as a single
/// line of JSON. This file is compiled into both the app and the command-line tool.
nonisolated enum ControlProtocol {

    /// Bumped whenever a message changes in a way an older peer can't decode
    static let version = 1

    /// The control socket for the app with the given bundle identifier.
    ///
    /// The socket lives in the per-user temporary directory, which only the user can
    /// access and which keeps the path well below the 104-byte limit of Unix socket paths.
    /// `confstr` is used rather than `$TMPDIR`, so a shell that overrides `TMPDIR` still
    /// finds the socket.
    static func socketPath(bundleIdentifier: String) -> String {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        let length = confstr(_CS_DARWIN_USER_TEMP_DIR, &buffer, buffer.count)
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        let directory = length > 0
            ? String(bytes: bytes, encoding: .utf8) ?? NSTemporaryDirectory()
            : NSTemporaryDirectory()
        return URL(filePath: directory).appending(path: "\(bundleIdentifier).sock").path(percentEncoded: false)
    }
}

// MARK: - Requests

nonisolated struct ControlRequest: Codable, Sendable {
    var version = ControlProtocol.version
    var command: ControlCommand
}

nonisolated enum ControlCommand: Codable, Sendable, Equatable {
    case status
    case listDisplays
    case listWindows
    case listApps
    case record(RecordOptions)
    case stop(copyToClipboard: Bool)
    case pause
    case resume
    /// Waits until the active recording ends
    case wait
}

nonisolated struct RecordOptions: Codable, Sendable, Equatable {
    var target: CaptureTarget
    /// Stops the recording automatically after this many seconds
    var durationSeconds: Double?
}

/// What to record. Queries match an ID first, then a name, see ``TargetResolver``.
nonisolated enum CaptureTarget: Codable, Sendable, Equatable {
    /// A display ID, `main`, or a display name
    case display(String)
    /// A window ID or title
    case window(String)
    /// A bundle identifier or application name
    case app(String)
    /// A rectangle in points, relative to the top-left corner of a display
    case area(AreaRect, display: String)
}

nonisolated struct AreaRect: Codable, Sendable, Equatable {
    var left: Double
    var top: Double
    var width: Double
    var height: Double
}

// MARK: - Responses

nonisolated struct ControlResponse: Codable, Sendable {
    var version = ControlProtocol.version
    var result: ControlResult?
    var error: ControlError?

    static func success(_ result: ControlResult) -> ControlResponse {
        ControlResponse(result: result)
    }

    static func failure(_ error: ControlError) -> ControlResponse {
        ControlResponse(error: error)
    }
}

nonisolated enum ControlResult: Codable, Sendable, Equatable {
    case status(RecorderStatus)
    case displays([DisplayInfo])
    case windows([WindowInfo])
    case apps([AppInfo])
    case recording(RecordingInfo)
}

nonisolated struct RecorderStatus: Codable, Sendable, Equatable {
    /// `idle`, `recording`, `paused` or `stopping`
    var state: String
    var durationSeconds: Double
    /// Where the active recording is written to, known as soon as it starts
    var outputPath: String?
}

nonisolated struct RecordingInfo: Codable, Sendable, Equatable {
    var outputPath: String
}

nonisolated struct DisplayInfo: Codable, Sendable, Equatable {
    var id: UInt32
    var name: String
    var isMain: Bool
    var width: Int
    var height: Int
}

nonisolated struct WindowInfo: Codable, Sendable, Equatable {
    var id: UInt32
    var title: String
    var appName: String
    var bundleID: String
}

nonisolated struct AppInfo: Codable, Sendable, Equatable {
    var bundleID: String
    var name: String
}

nonisolated struct ControlError: Error, Codable, Sendable, Equatable {

    enum Code: String, Codable, Sendable {
        case invalidRequest = "invalid_request"
        case unsupportedVersion = "unsupported_version"
        /// The user hasn't allowed command-line control in Settings
        case disabled
        case notFound = "not_found"
        case ambiguous
        case alreadyRecording = "already_recording"
        case notRecording = "not_recording"
        case permissionDenied = "permission_denied"
        case failed
    }

    var code: Code
    var message: String
    /// The matches of an ambiguous target, so the caller can pick one by ID
    var candidates: [String]?
}
