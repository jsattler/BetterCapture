//
//  SkillShowCommand.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

import ArgumentParser
import Foundation

struct SkillShowCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Print a guide that teaches AI agents how to use this tool."
    )

    func run() {
        print(SkillGuide.text(toolPath: ControlClient.current().appURL?
            .appending(path: "Contents/Helpers/bettercapture")
            .path(percentEncoded: false)))
    }
}
