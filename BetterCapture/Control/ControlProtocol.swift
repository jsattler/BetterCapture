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

    /// Dates are sent as ISO 8601 strings, so the JSON the tool prints is readable
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// MARK: - Requests

nonisolated struct ControlRequest: Codable, Sendable {
    var version = ControlProtocol.version
    var command: ControlCommand
}

/// Commands that act on a recording take a ``RecordingSelector``. Without one, they act on
/// the only active recording and fail as ambiguous when several are active.
nonisolated enum ControlCommand: Codable, Sendable, Equatable {
    /// Lists the active and recently ended recordings, or the selected one
    case status(RecordingSelector?)
    case listDisplays
    case listWindows
    case listApps
    case record(RecordOptions)
    /// Stops the selected recording, or every active one when `all` is set
    case stop(RecordingSelector?, all: Bool, copyToClipboard: Bool)
    case pause(RecordingSelector?)
    case resume(RecordingSelector?)
    /// Waits until the selected recording ends
    case wait(RecordingSelector?)
}

/// A recording's ID or name, matched the same way as capture targets, see ``TargetResolver``
typealias RecordingSelector = String

nonisolated struct RecordOptions: Codable, Sendable, Equatable {
    var target: CaptureTarget
    /// A label to tell the recording apart from others, also accepted in place of its ID
    var name: String?
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
    case displays([DisplayInfo])
    case windows([WindowInfo])
    case apps([AppInfo])
    case recording(RecordingInfo)
    case recordings([RecordingInfo])
}

/// A recording started from the command line, active or recently ended
nonisolated struct RecordingInfo: Codable, Sendable, Equatable {

    enum State: String, Codable, Sendable {
        case recording, paused, stopping
        /// Saved to ``RecordingInfo/outputPath``
        case finished
        /// Ended without a usable file, see ``RecordingInfo/error``
        case failed
    }

    /// A short ID, unique while the app runs
    var id: String
    var name: String?
    var state: State
    /// What is recorded, such as `display 1`, `window 1234 "Inbox"` or `app com.apple.Safari`
    var target: String
    var startedAt: Date
    var endedAt: Date?
    /// Recorded time, excluding pauses
    var durationSeconds: Double
    /// Where the recording is written to, known as soon as it starts
    var outputPath: String
    /// Why a failed recording ended
    var error: String?
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
        case notRecording = "not_recording"
        case permissionDenied = "permission_denied"
        case failed
    }

    var code: Code
    var message: String
    /// The matches of an ambiguous target, so the caller can pick one by ID
    var candidates: [String]?
}
