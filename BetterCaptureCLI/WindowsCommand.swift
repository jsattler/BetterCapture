//
//  WindowsCommand.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

import ArgumentParser

struct WindowsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "windows",
        abstract: "List the on-screen windows that can be recorded."
    )

    @OptionGroup var output: OutputOptions

    func run() throws {
        guard case .windows(let windows) = try output.send(.listWindows) else { throw output.unexpectedResponse() }

        output.emit(["windows": windows], human: TextTable.render(
            header: ["ID", "APP", "TITLE"],
            rows: windows.map { [String($0.id), $0.appName, $0.title] }
        ))
    }
}
