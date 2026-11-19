//
//  AppsCommand.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

import ArgumentParser

struct AppsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apps",
        abstract: "List the apps with on-screen windows that can be recorded."
    )

    @OptionGroup var output: OutputOptions

    func run() throws {
        guard case .apps(let apps) = try output.send(.listApps) else { throw output.unexpectedResponse() }

        output.emit(["apps": apps], human: TextTable.render(
            header: ["BUNDLE ID", "NAME"],
            rows: apps.map { [$0.bundleID, $0.name] }
        ))
    }
}
