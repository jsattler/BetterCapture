//
//  PauseCommand.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

import ArgumentParser

struct PauseCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pause",
        abstract: "Pause a recording. Paused time is left out of the file."
    )

    @OptionGroup var selection: RecordingArgument
    @OptionGroup var output: OutputOptions

    func run() throws {
        guard case .recording(let recording) = try output.send(.pause(selection.recording), launchIfNeeded: false) else {
            throw output.unexpectedResponse()
        }
        output.emit(recording, human: recording.text)
    }
}
