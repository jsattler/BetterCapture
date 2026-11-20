//
//  CLIError.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

import Foundation

/// An error reported to the user, with the exit code it ends the process with
struct CLIError: Error, Encodable {
    var code: String
    var message: String
    var candidates: [String]?
    var exitCode: Int32

    /// The exit code is reported through the process, not the JSON
    private enum CodingKeys: String, CodingKey {
        case code, message, candidates
    }

    init(code: String, message: String, candidates: [String]? = nil, exitCode: Int32) {
        self.code = code
        self.message = message
        self.candidates = candidates
        self.exitCode = exitCode
    }

    init(_ error: ControlError) {
        let exitCode: Int32 = switch error.code {
        case .invalidRequest: 2
        case .notFound, .ambiguous: 3
        case .disabled, .permissionDenied: 5
        case .unsupportedVersion, .notRecording, .failed: 1
        }
        self.init(code: error.code.rawValue, message: error.message, candidates: error.candidates, exitCode: exitCode)
    }

    static func unreachable(_ message: String) -> CLIError {
        CLIError(code: "unreachable", message: message, exitCode: 4)
    }

    static let invalidResponse = CLIError(
        code: "invalid_response",
        message: "BetterCapture sent a response this tool doesn't understand.",
        exitCode: 1
    )
}
