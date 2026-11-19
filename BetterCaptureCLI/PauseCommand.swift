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
        abstract: "Pause the recording. Paused time is left out of the file."
    )

    @OptionGroup var output: OutputOptions

    func run() throws {
        guard case .status(let status) = try output.send(.pause, launchIfNeeded: false) else { throw output.unexpectedResponse() }
        output.emit(status, human: status.text)
    }
}
