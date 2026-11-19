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
        abstract: "Wait until the recording ends, then print the saved file's path.",
        discussion: "Ctrl-C stops waiting but keeps the recording running."
    )

    @OptionGroup var output: OutputOptions

    func run() throws {
        guard case .recording(let recording) = try output.send(.wait, launchIfNeeded: false) else {
            throw output.unexpectedResponse()
        }
        output.emit(recording, human: recording.outputPath)
    }
}
