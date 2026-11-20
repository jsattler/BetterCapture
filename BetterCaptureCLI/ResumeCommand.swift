//
//  ResumeCommand.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

import ArgumentParser

struct ResumeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "resume",
        abstract: "Resume a paused recording."
    )

    @OptionGroup var selection: RecordingArgument
    @OptionGroup var output: OutputOptions

    func run() throws {
        guard case .recording(let recording) = try output.send(.resume(selection.recording), launchIfNeeded: false) else {
            throw output.unexpectedResponse()
        }
        output.emit(recording, human: recording.text)
    }
}
