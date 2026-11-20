//
//  StopCommand.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

import ArgumentParser

struct StopCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop a recording and print the saved file's path."
    )

    @OptionGroup var selection: RecordingArgument

    @Flag(help: "Stop every recording in progress.")
    var all = false

    @Flag(help: "Also copy the recording to the clipboard. Ignored with --all when more than one recording stops.")
    var copy = false

    @OptionGroup var output: OutputOptions

    func validate() throws {
        if all, selection.recording != nil {
            throw ValidationError("Pass either a recording or --all, not both.")
        }
    }

    func run() throws {
        let command = ControlCommand.stop(selection.recording, all: all, copyToClipboard: copy)

        switch try output.send(command, launchIfNeeded: false) {
        case .recording(let recording):
            output.emit(recording, human: recording.outputPath)

        case .recordings(let recordings):
            output.emit(["recordings": recordings], human: recordings.map {
                $0.state == .finished ? $0.outputPath : "\($0.id) failed: \($0.error ?? "")"
            }.joined(separator: "\n"))

            if recordings.contains(where: { $0.state == .failed }) {
                throw ExitCode.failure
            }

        default:
            throw output.unexpectedResponse()
        }
    }
}
