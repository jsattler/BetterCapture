//
//  BetterCaptureCLI.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

import ArgumentParser
import Foundation

@main
struct BetterCaptureCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bettercapture",
        abstract: "Control BetterCapture screen recordings from the command line.",
        discussion: """
            Commands are carried out by the BetterCapture app, which is launched if it isn't \
            running. Turn on "Allow Command-Line Control" in BetterCapture Settings → Command Line first.

            Exit codes: 0 success, 1 failure, 2 invalid command line, 3 target not found or \
            ambiguous, 4 BetterCapture not reachable, 5 permission missing or command-line control turned off.

            AI agents: run `bettercapture skill show` for a usage guide.
            """,
        version: ControlClient.current().appVersion,
        subcommands: [
            StatusCommand.self,
            RecordCommand.self,
            StopCommand.self,
            PauseCommand.self,
            ResumeCommand.self,
            WaitCommand.self,
            DisplaysCommand.self,
            WindowsCommand.self,
            AppsCommand.self,
            SkillCommand.self
        ]
    )

    /// Replaces ArgumentParser's entry point so an invalid command line exits with 2, like
    /// most command-line tools, rather than ArgumentParser's default of 64
    static func main() {
        do {
            var command = try parseAsRoot()
            try command.run()
        } catch {
            let code = exitCode(for: error)
            let message = fullMessage(for: error)

            if code == .success {
                if !message.isEmpty { print(message) }
                Foundation.exit(0)
            }

            if !message.isEmpty {
                FileHandle.standardError.write(Data((message + "\n").utf8))
            }
            Foundation.exit(code == .validationFailure ? 2 : code.rawValue)
        }
    }
}
