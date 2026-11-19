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
        abstract: "Stop the recording and print the saved file's path."
    )

    @Flag(help: "Also copy the recording to the clipboard.")
    var copy = false

    @OptionGroup var output: OutputOptions

    func run() throws {
        guard case .recording(let recording) = try output.send(.stop(copyToClipboard: copy), launchIfNeeded: false) else {
            throw output.unexpectedResponse()
        }
        output.emit(recording, human: recording.outputPath)
    }
}
