//
//  StatusCommand.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

import ArgumentParser

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "List the recordings in progress and those that ended recently.",
        discussion: "Pass a recording's ID or name to show only that one."
    )

    @Argument(help: "ID or name of a recording.")
    var recording: String?

    @OptionGroup var output: OutputOptions

    func run() throws {
        guard case .recordings(let recordings) = try output.send(.status(recording)) else { throw output.unexpectedResponse() }
        output.emit(["recordings": recordings], human: RecordingInfo.table(recordings))
    }
}
