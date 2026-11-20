//
//  WaitCommand.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

import ArgumentParser

struct WaitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "wait",
        abstract: "Wait until a recording ends, then print the saved file's path.",
        discussion: "Returns right away for a recording that has already ended. Ctrl-C stops waiting but keeps the recording running."
    )

    @OptionGroup var selection: RecordingArgument
    @OptionGroup var output: OutputOptions

    func run() throws {
        guard case .recording(let recording) = try output.send(.wait(selection.recording), launchIfNeeded: false) else {
            throw output.unexpectedResponse()
        }
        output.emit(recording, human: recording.outputPath)
    }
}
