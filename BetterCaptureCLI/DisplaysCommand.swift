//
//  DisplaysCommand.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

import ArgumentParser

struct DisplaysCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "displays",
        abstract: "List the displays that can be recorded."
    )

    @OptionGroup var output: OutputOptions

    func run() throws {
        guard case .displays(let displays) = try output.send(.listDisplays) else { throw output.unexpectedResponse() }

        output.emit(["displays": displays], human: TextTable.render(
            header: ["ID", "SIZE", "MAIN", "NAME"],
            rows: displays.map { [String($0.id), "\($0.width)x\($0.height)", $0.isMain ? "yes" : "", $0.name] }
        ))
    }
}
