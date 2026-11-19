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
        abstract: "Show whether BetterCapture is recording, and where to."
    )

    @OptionGroup var output: OutputOptions

    func run() throws {
        guard case .status(let status) = try output.send(.status) else { throw output.unexpectedResponse() }
        output.emit(status, human: status.text)
    }
}
