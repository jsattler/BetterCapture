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

    @OptionGroup var output: OutputOptions

    func run() throws {
        guard case .status(let status) = try output.send(.resume, launchIfNeeded: false) else { throw output.unexpectedResponse() }
        output.emit(status, human: status.text)
    }
}
