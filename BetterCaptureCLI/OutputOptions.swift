//
//  OutputOptions.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

import ArgumentParser
import Foundation

/// The `--json` flag, and printing of results and errors in either format
struct OutputOptions: ParsableArguments {

    @Flag(help: "Print machine-readable JSON.")
    var json = false

    /// Sends a command to the app. On failure the error is printed and the process exits with its code.
    func send(_ command: ControlCommand, launchIfNeeded: Bool = true) throws -> ControlResult {
        do {
            return try ControlClient.current().send(command, launchIfNeeded: launchIfNeeded)
        } catch {
            report(error)
            throw ExitCode(error.exitCode)
        }
    }

    /// Prints a result as JSON, or as the given text
    func emit(_ value: some Encodable, human: @autoclosure () -> String) {
        if json {
            print(Self.encode(value))
        } else {
            print(human())
        }
    }

    /// Prints an error to standard error
    func report(_ error: CLIError) {
        if json {
            printError(Self.encode(["error": error]))
            return
        }

        printError("Error: \(error.message)")
        for candidate in error.candidates ?? [] {
            printError("  \(candidate)")
        }
    }

    /// Reports a result of the wrong kind, which only happens if the app and tool disagree
    func unexpectedResponse() -> ExitCode {
        report(.invalidResponse)
        return ExitCode(CLIError.invalidResponse.exitCode)
    }

    func printError(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    private static func encode(_ value: some Encodable) -> String {
        let encoder = ControlProtocol.makeEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(value) else { return "{}" }
        return String(bytes: data, encoding: .utf8) ?? "{}"
    }
}
